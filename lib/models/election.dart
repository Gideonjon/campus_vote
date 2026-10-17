import 'package:cloud_firestore/cloud_firestore.dart';

class Candidate {
  final String id;
  final String name;
  final String bio;

  const Candidate({required this.id, required this.name, this.bio = ''});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'bio': bio};

  factory Candidate.fromMap(Map<String, dynamic> m) => Candidate(
        id: m['id'] as String,
        name: m['name'] as String? ?? '',
        bio: m['bio'] as String? ?? '',
      );
}

class Position {
  final String id;
  final String title;
  final List<Candidate> candidates;

  const Position({
    required this.id,
    required this.title,
    required this.candidates,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'candidates': candidates.map((c) => c.toMap()).toList(),
      };

  factory Position.fromMap(Map<String, dynamic> m) => Position(
        id: m['id'] as String,
        title: m['title'] as String? ?? '',
        candidates: ((m['candidates'] as List?) ?? const [])
            .map((c) => Candidate.fromMap(Map<String, dynamic>.from(c as Map)))
            .toList(),
      );

  Candidate? candidate(String id) {
    for (final c in candidates) {
      if (c.id == id) return c;
    }
    return null;
  }
}

enum ElectionStatus { draft, open, closed, published }

extension ElectionStatusLabel on ElectionStatus {
  String get label => switch (this) {
        ElectionStatus.draft => 'Draft',
        ElectionStatus.open => 'Open',
        ElectionStatus.closed => 'Closed',
        ElectionStatus.published => 'Results out',
      };
}

class Election {
  final String id;
  final String title;
  final String description;
  final String hostId;
  final String hostName;
  final ElectionStatus status;
  final DateTime startAt;
  final DateTime endAt;
  final List<Position> positions;
  final String publicKey;
  final bool requiresOfficerKey;
  final int eligibleCount;
  final DateTime? createdAt;

  const Election({
    required this.id,
    required this.title,
    required this.description,
    required this.hostId,
    required this.hostName,
    required this.status,
    required this.startAt,
    required this.endAt,
    required this.positions,
    required this.publicKey,
    required this.requiresOfficerKey,
    required this.eligibleCount,
    this.createdAt,
  });

  bool get hasStarted => !DateTime.now().isBefore(startAt);
  bool get hasEnded => !DateTime.now().isBefore(endAt);
  bool get isWithinWindow => hasStarted && !hasEnded;
  bool get acceptingVotes => status == ElectionStatus.open && isWithinWindow;

  factory Election.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final statusName = d['status'] as String? ?? 'draft';
    return Election(
      id: doc.id,
      title: d['title'] as String? ?? 'Untitled election',
      description: d['description'] as String? ?? '',
      hostId: d['hostId'] as String? ?? '',
      hostName: d['hostName'] as String? ?? '',
      status: ElectionStatus.values.firstWhere(
        (s) => s.name == statusName,
        orElse: () => ElectionStatus.draft,
      ),
      startAt: (d['startAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endAt: (d['endAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      positions: ((d['positions'] as List?) ?? const [])
          .map((p) => Position.fromMap(Map<String, dynamic>.from(p as Map)))
          .toList(),
      publicKey: d['publicKey'] as String? ?? '',
      requiresOfficerKey: d['requiresOfficerKey'] as bool? ?? false,
      eligibleCount: (d['eligibleCount'] as num?)?.toInt() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class EligibleVoter {
  final String id;
  final String label;
  final bool used;

  const EligibleVoter({required this.id, required this.label, required this.used});

  factory EligibleVoter.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return EligibleVoter(
      id: doc.id,
      label: d['label'] as String? ?? doc.id,
      used: d['used'] as bool? ?? false,
    );
  }
}

class ElectionResults {
  /// positionId -> candidateId -> votes
  final Map<String, Map<String, int>> tally;
  final int totalBallots;
  final int validBallots;
  final int invalidBallots;
  final int voterCount;
  final List<String> receipts;
  final DateTime? publishedAt;

  const ElectionResults({
    required this.tally,
    required this.totalBallots,
    required this.validBallots,
    required this.invalidBallots,
    required this.voterCount,
    required this.receipts,
    this.publishedAt,
  });

  /// Every voter record should have exactly one ballot.
  bool get integrityOk => totalBallots == voterCount;

  Map<String, dynamic> toMap() => {
        'tally': tally,
        'totalBallots': totalBallots,
        'validBallots': validBallots,
        'invalidBallots': invalidBallots,
        'voterCount': voterCount,
        'receipts': receipts,
        'publishedAt': FieldValue.serverTimestamp(),
      };

  factory ElectionResults.fromMap(Map<String, dynamic> d) {
    final raw = Map<String, dynamic>.from((d['tally'] as Map?) ?? const {});
    return ElectionResults(
      tally: raw.map(
        (pos, cands) => MapEntry(
          pos,
          Map<String, dynamic>.from(cands as Map)
              .map((c, n) => MapEntry(c, (n as num).toInt())),
        ),
      ),
      totalBallots: (d['totalBallots'] as num?)?.toInt() ?? 0,
      validBallots: (d['validBallots'] as num?)?.toInt() ?? 0,
      invalidBallots: (d['invalidBallots'] as num?)?.toInt() ?? 0,
      voterCount: (d['voterCount'] as num?)?.toInt() ?? 0,
      receipts: ((d['receipts'] as List?) ?? const []).cast<String>(),
      publishedAt: (d['publishedAt'] as Timestamp?)?.toDate(),
    );
  }
}
