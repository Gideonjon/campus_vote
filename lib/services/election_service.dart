import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/election.dart';
import 'ballot_crypto.dart';
import 'key_store.dart';

enum EligibilityStatus { ok, notListed, usedByOther }

class ElectionService {
  ElectionService._();
  static final instance = ElectionService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _elections =>
      _db.collection('elections');

  DocumentReference<Map<String, dynamic>> _ref(String id) =>
      _elections.doc(id);

  /// Matric numbers like "18/CS/1234" can't be Firestore ids ("/"), so they
  /// are normalised to "18-CS-1234".
  static String normalizeMatric(String raw) => raw
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  // ------------------------------------------------------------ reading

  Stream<Election?> watchElection(String id) => _ref(id)
      .snapshots()
      .map((d) => d.exists ? Election.fromDoc(d) : null);

  Future<Election?> getElection(String id) async {
    final d = await _ref(id).get();
    return d.exists ? Election.fromDoc(d) : null;
  }

  Stream<List<Election>> watchMyElections(String uid) => _elections
          .where('hostId', isEqualTo: uid)
          .snapshots()
          .map((s) {
        final list = s.docs.map(Election.fromDoc).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime.now())
            .compareTo(a.createdAt ?? DateTime.now()));
        return list;
      });

  Stream<int> watchVoterCount(String id) =>
      _ref(id).collection('voters').snapshots().map((s) => s.size);

  Stream<List<EligibleVoter>> watchEligible(String id) => _ref(id)
      .collection('eligible')
      .snapshots()
      .map((s) {
        final list = s.docs.map(EligibleVoter.fromDoc).toList();
        list.sort((a, b) => a.label.compareTo(b.label));
        return list;
      });

  Stream<ElectionResults?> watchResults(String id) => _ref(id)
      .collection('public')
      .doc('results')
      .snapshots()
      .map((d) => d.exists ? ElectionResults.fromMap(d.data()!) : null);

  // -------------------------------------------------------------- host

  /// Creates a draft election, generates its key pair and saves the host's
  /// key share on this device. Returns the new id and the keys to back up.
  Future<(String, ElectionKeys)> createElection({
    required User host,
    required String title,
    required String description,
    required DateTime startAt,
    required DateTime endAt,
    required List<Position> positions,
    required bool withOfficer,
  }) async {
    final keys = await BallotCrypto.generateElectionKeys(withOfficer: withOfficer);
    final doc = _elections.doc();
    await doc.set({
      'title': title.trim(),
      'description': description.trim(),
      'hostId': host.uid,
      'hostName': host.displayName ?? host.email ?? 'Host',
      'status': ElectionStatus.draft.name,
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      'positions': positions.map((p) => p.toMap()).toList(),
      'publicKey': keys.publicKeyB64,
      'requiresOfficerKey': withOfficer,
      'eligibleCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await KeyStore.saveHostShare(doc.id, keys.hostShare);
    return (doc.id, keys);
  }

  Future<void> setStatus(String id, ElectionStatus status) =>
      _ref(id).update({'status': status.name});

  Future<void> updateWindow(String id, DateTime start, DateTime end) =>
      _ref(id).update({
        'startAt': Timestamp.fromDate(start),
        'endAt': Timestamp.fromDate(end),
      });

  Future<void> deleteDraft(String id) => _ref(id).delete();

  /// Adds matric numbers (one per line, or separated by commas/semicolons).
  /// Returns how many were written.
  Future<int> addEligible(String id, String rawText) async {
    final seen = <String>{};
    final entries = <MapEntry<String, String>>[];
    for (final part in rawText.split(RegExp(r'[\n,;\t]+'))) {
      final label = part.trim();
      if (label.isEmpty) continue;
      final key = normalizeMatric(label);
      if (key.isEmpty || !seen.add(key)) continue;
      entries.add(MapEntry(key, label.toUpperCase()));
    }

    final col = _ref(id).collection('eligible');
    for (var i = 0; i < entries.length; i += 400) {
      final batch = _db.batch();
      for (final e in entries.skip(i).take(400)) {
        batch.set(col.doc(e.key), {
          'label': e.value,
          'used': false,
          'usedBy': null,
        });
      }
      await batch.commit();
    }
    await _recountEligible(id);
    return entries.length;
  }

  Future<void> removeEligible(String id, String matricId) async {
    await _ref(id).collection('eligible').doc(matricId).delete();
    await _recountEligible(id);
  }

  Future<void> _recountEligible(String id) async {
    final agg = await _ref(id).collection('eligible').count().get();
    await _ref(id).update({'eligibleCount': agg.count ?? 0});
  }

  /// Downloads every ballot, decrypts it on this device and publishes totals.
  Future<ElectionResults> tallyAndPublish({
    required Election election,
    required List<int> seed,
  }) async {
    final ref = _ref(election.id);
    final ballots = await ref.collection('ballots').get();
    final voters = await ref.collection('voters').count().get();
    final keyPair = await BallotCrypto.keyPairFromSeed(seed);

    final Map<String, Map<String, int>> tally = {
      for (final p in election.positions)
        p.id: {for (final c in p.candidates) c.id: 0},
    };

    var valid = 0;
    var invalid = 0;
    final receipts = <String>[];

    for (final doc in ballots.docs) {
      EncryptedBallot ballot;
      try {
        ballot = EncryptedBallot.fromMap(doc.data());
      } catch (_) {
        invalid++;
        continue;
      }
      receipts.add(await BallotCrypto.receiptFor(ballot.ct));

      try {
        final choices = await BallotCrypto.decrypt(
          ballot: ballot,
          electionKeyPair: keyPair,
          electionId: election.id,
        );
        final complete = choices.length == election.positions.length &&
            election.positions.every((p) =>
                choices[p.id] != null &&
                tally[p.id]!.containsKey(choices[p.id]));
        if (!complete) {
          invalid++;
          continue;
        }
        choices.forEach((pos, cand) {
          tally[pos]![cand] = tally[pos]![cand]! + 1;
        });
        valid++;
      } catch (_) {
        invalid++;
      }
    }

    receipts.sort();
    final results = ElectionResults(
      tally: tally,
      totalBallots: ballots.size,
      validBallots: valid,
      invalidBallots: invalid,
      voterCount: voters.count ?? 0,
      receipts: receipts,
    );

    await ref.collection('public').doc('results').set(results.toMap());
    await setStatus(election.id, ElectionStatus.published);
    return results;
  }

  // ------------------------------------------------------------- voter

  Future<bool> hasVoted(String electionId, String uid) async {
    final d = await _ref(electionId).collection('voters').doc(uid).get();
    return d.exists;
  }

  Future<(EligibilityStatus, String)> checkEligibility(
    String electionId,
    String rawMatric,
    String uid,
  ) async {
    final matric = normalizeMatric(rawMatric);
    if (matric.isEmpty) return (EligibilityStatus.notListed, matric);
    final d = await _ref(electionId).collection('eligible').doc(matric).get();
    if (!d.exists) return (EligibilityStatus.notListed, matric);
    final data = d.data()!;
    if (data['used'] == true && data['usedBy'] != uid) {
      return (EligibilityStatus.usedByOther, matric);
    }
    return (EligibilityStatus.ok, matric);
  }

  /// Encrypts the ballot on this device and submits it in ONE atomic batch:
  ///  1. voters/{uid}       -> records that this person voted (no choices)
  ///  2. eligible/{matric}  -> marks the matric number as used
  ///  3. ballots/{random}   -> the encrypted ballot, with nothing linking it to the voter
  /// Returns the voter's receipt code.
  Future<String> castVote({
    required Election election,
    required String uid,
    required String matric,
    required Map<String, String> choices,
  }) async {
    final ballot = await BallotCrypto.encrypt(
      electionId: election.id,
      publicKeyB64: election.publicKey,
      choices: choices,
    );

    final ref = _ref(election.id);
    final batch = _db.batch();
    batch.set(ref.collection('voters').doc(uid), {
      'matric': matric,
      'votedAt': FieldValue.serverTimestamp(),
    });
    batch.update(ref.collection('eligible').doc(matric), {
      'used': true,
      'usedBy': uid,
    });
    batch.set(ref.collection('ballots').doc(), ballot.toMap());
    await batch.commit();

    final receipt = await BallotCrypto.receiptFor(ballot.ct);
    await KeyStore.saveReceipt(election.id, receipt);
    return receipt;
  }
}
