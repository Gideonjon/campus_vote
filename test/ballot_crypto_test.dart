import 'package:campus_vote/services/ballot_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const electionId = 'test-election-123';
  final choices = {'p1': 'p1c2', 'p2': 'p2c1'};

  test('ballot round-trips with the election key', () async {
    final keys = await BallotCrypto.generateElectionKeys(withOfficer: false);
    final ballot = await BallotCrypto.encrypt(
      electionId: electionId,
      publicKeyB64: keys.publicKeyB64,
      choices: choices,
    );
    final kp = await BallotCrypto.keyPairFromSeed(keys.hostShare);
    final out = await BallotCrypto.decrypt(
      ballot: ballot,
      electionKeyPair: kp,
      electionId: electionId,
    );
    expect(out, choices);
  });

  test('two ballots with the same choices look completely different', () async {
    final keys = await BallotCrypto.generateElectionKeys(withOfficer: false);
    final a = await BallotCrypto.encrypt(
        electionId: electionId, publicKeyB64: keys.publicKeyB64, choices: choices);
    final b = await BallotCrypto.encrypt(
        electionId: electionId, publicKeyB64: keys.publicKeyB64, choices: choices);
    expect(a.ct, isNot(b.ct));
    expect(a.epk, isNot(b.epk));
    expect(a.ct.length, b.ct.length); // padded to the same size
  });

  test('wrong key cannot decrypt', () async {
    final keys = await BallotCrypto.generateElectionKeys(withOfficer: false);
    final other = await BallotCrypto.generateElectionKeys(withOfficer: false);
    final ballot = await BallotCrypto.encrypt(
        electionId: electionId, publicKeyB64: keys.publicKeyB64, choices: choices);
    final wrong = await BallotCrypto.keyPairFromSeed(other.hostShare);
    expect(
      () => BallotCrypto.decrypt(ballot: ballot, electionKeyPair: wrong, electionId: electionId),
      throwsA(anything),
    );
  });

  test('ballot from another election is rejected', () async {
    final keys = await BallotCrypto.generateElectionKeys(withOfficer: false);
    final ballot = await BallotCrypto.encrypt(
        electionId: electionId, publicKeyB64: keys.publicKeyB64, choices: choices);
    final kp = await BallotCrypto.keyPairFromSeed(keys.hostShare);
    expect(
      () => BallotCrypto.decrypt(ballot: ballot, electionKeyPair: kp, electionId: 'other'),
      throwsA(anything),
    );
  });

  test('officer split: both shares are needed', () async {
    final keys = await BallotCrypto.generateElectionKeys(withOfficer: true);
    expect(await BallotCrypto.keyMatches(keys.hostShare, keys.publicKeyB64), isFalse);
    expect(await BallotCrypto.keyMatches(keys.officerShare!, keys.publicKeyB64), isFalse);
    final seed = BallotCrypto.xor(keys.hostShare, keys.officerShare!);
    expect(await BallotCrypto.keyMatches(seed, keys.publicKeyB64), isTrue);
  });

  test('key text encodes and decodes', () async {
    final keys = await BallotCrypto.generateElectionKeys(withOfficer: false);
    final text = BallotCrypto.encodeKey(BallotCrypto.hostKeyPrefix, keys.hostShare);
    expect(BallotCrypto.decodeKey(text), keys.hostShare);
    expect(BallotCrypto.decodeKey('  $text\n'), keys.hostShare);
  });

  test('receipt is stable and formatted', () async {
    final keys = await BallotCrypto.generateElectionKeys(withOfficer: false);
    final ballot = await BallotCrypto.encrypt(
        electionId: electionId, publicKeyB64: keys.publicKeyB64, choices: choices);
    final r1 = await BallotCrypto.receiptFor(ballot.ct);
    final r2 = await BallotCrypto.receiptFor(ballot.ct);
    expect(r1, r2);
    expect(r1, matches(RegExp(r'^[0-9A-F]{4}(-[0-9A-F]{4}){3}$')));
  });
}
