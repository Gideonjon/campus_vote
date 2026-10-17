import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Keys created when a host sets up an election.
///
/// The election private key is a 32-byte X25519 seed. It is never uploaded.
/// - Without an electoral officer: hostShare == seed.
/// - With an electoral officer: seed = hostShare XOR officerShare, so neither
///   person alone can decrypt the ballots.
class ElectionKeys {
  final String publicKeyB64;
  final List<int> hostShare;
  final List<int>? officerShare;

  const ElectionKeys({
    required this.publicKeyB64,
    required this.hostShare,
    this.officerShare,
  });
}

/// An encrypted ballot exactly as stored in Firestore.
class EncryptedBallot {
  final String epk; // voter's one-time (ephemeral) public key
  final String nonce;
  final String ct; // ciphertext
  final String mac; // AES-GCM authentication tag

  const EncryptedBallot({
    required this.epk,
    required this.nonce,
    required this.ct,
    required this.mac,
  });

  Map<String, dynamic> toMap() =>
      {'epk': epk, 'nonce': nonce, 'ct': ct, 'mac': mac};

  factory EncryptedBallot.fromMap(Map<String, dynamic> m) => EncryptedBallot(
        epk: m['epk'] as String,
        nonce: m['nonce'] as String,
        ct: m['ct'] as String,
        mac: m['mac'] as String,
      );
}

/// Hybrid public-key encryption for ballots (an "ECIES / sealed box" design):
///
///   1. Voter device creates a one-time X25519 key pair.
///   2. X25519(one-time private, election public) -> shared secret.
///   3. HKDF-SHA256(shared secret) -> 256-bit AES key.
///   4. AES-256-GCM encrypts the padded ballot; the election id is bound in
///      as associated data so a ballot can't be replayed in another election.
///
/// Only the holder of the election private key can rebuild the shared secret.
class BallotCrypto {
  static final _x25519 = X25519();
  static final _aes = AesGcm.with256bits();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  static const _info = 'campusvote-ballot-v1';

  /// Every ballot is padded to the same size so ciphertext length leaks nothing.
  static const paddedLength = 1024;

  static const hostKeyPrefix = 'CVHOST';
  static const officerKeyPrefix = 'CVOFFICER';

  static List<int> randomBytes(int length) {
    final r = Random.secure();
    return List<int>.generate(length, (_) => r.nextInt(256));
  }

  static List<int> xor(List<int> a, List<int> b) {
    if (a.length != b.length) {
      throw ArgumentError('Key shares have different lengths.');
    }
    return List<int>.generate(a.length, (i) => a[i] ^ b[i]);
  }

  // ---------------------------------------------------------------- keys

  static Future<ElectionKeys> generateElectionKeys({
    required bool withOfficer,
  }) async {
    final seed = randomBytes(32);
    final keyPair = await _x25519.newKeyPairFromSeed(seed);
    final publicKey = await keyPair.extractPublicKey();
    final pubB64 = base64Encode(publicKey.bytes);

    if (!withOfficer) {
      return ElectionKeys(publicKeyB64: pubB64, hostShare: seed);
    }
    final officerShare = randomBytes(32);
    return ElectionKeys(
      publicKeyB64: pubB64,
      hostShare: xor(seed, officerShare),
      officerShare: officerShare,
    );
  }

  static Future<SimpleKeyPair> keyPairFromSeed(List<int> seed) =>
      _x25519.newKeyPairFromSeed(seed);

  /// True if [seed] is the private key for [publicKeyB64].
  static Future<bool> keyMatches(List<int> seed, String publicKeyB64) async {
    if (seed.length != 32) return false;
    final kp = await _x25519.newKeyPairFromSeed(seed);
    final pub = await kp.extractPublicKey();
    return base64Encode(pub.bytes) == publicKeyB64;
  }

  /// Human-copyable key text, e.g. "CVHOST:3q2-7w...".
  static String encodeKey(String prefix, List<int> bytes) =>
      '$prefix:${base64Url.encode(bytes)}';

  static List<int> decodeKey(String text) {
    var t = text.trim();
    final i = t.indexOf(':');
    if (i >= 0) t = t.substring(i + 1);
    t = t.replaceAll(RegExp(r'\s'), '');
    final bytes = base64Url.decode(base64Url.normalize(t));
    if (bytes.length != 32) {
      throw const FormatException('That key is not the right length.');
    }
    return bytes;
  }

  // ----------------------------------------------------------- encryption

  static Future<SecretKey> _deriveKey(
    SecretKey shared,
    List<int> ephemeralPublic,
    String electionId,
  ) {
    return _hkdf.deriveKey(
      secretKey: shared,
      nonce: utf8.encode(electionId),
      info: [...utf8.encode(_info), ...ephemeralPublic],
    );
  }

  static Future<EncryptedBallot> encrypt({
    required String electionId,
    required String publicKeyB64,
    required Map<String, String> choices,
  }) async {
    final payload = utf8.encode(jsonEncode({'e': electionId, 'v': choices}));
    if (payload.length > paddedLength - 2) {
      throw StateError('Ballot is too large.');
    }

    // [2-byte length][payload][random padding]
    final padded = Uint8List(paddedLength);
    padded[0] = (payload.length >> 8) & 0xff;
    padded[1] = payload.length & 0xff;
    padded.setRange(2, 2 + payload.length, payload);
    final filler = randomBytes(paddedLength - 2 - payload.length);
    padded.setRange(2 + payload.length, paddedLength, filler);

    final ephemeral = await _x25519.newKeyPair();
    final ephemeralPublic = await ephemeral.extractPublicKey();
    final shared = await _x25519.sharedSecretKey(
      keyPair: ephemeral,
      remotePublicKey: SimplePublicKey(
        base64Decode(publicKeyB64),
        type: KeyPairType.x25519,
      ),
    );
    final key = await _deriveKey(shared, ephemeralPublic.bytes, electionId);

    final box = await _aes.encrypt(
      padded,
      secretKey: key,
      nonce: _aes.newNonce(),
      aad: utf8.encode(electionId),
    );

    return EncryptedBallot(
      epk: base64Encode(ephemeralPublic.bytes),
      nonce: base64Encode(box.nonce),
      ct: base64Encode(box.cipherText),
      mac: base64Encode(box.mac.bytes),
    );
  }

  /// Decrypts a ballot. Throws if the key is wrong or the ballot was tampered
  /// with (AES-GCM authentication fails) or belongs to another election.
  static Future<Map<String, String>> decrypt({
    required EncryptedBallot ballot,
    required SimpleKeyPair electionKeyPair,
    required String electionId,
  }) async {
    final epk = base64Decode(ballot.epk);
    final shared = await _x25519.sharedSecretKey(
      keyPair: electionKeyPair,
      remotePublicKey: SimplePublicKey(epk, type: KeyPairType.x25519),
    );
    final key = await _deriveKey(shared, epk, electionId);

    final clear = await _aes.decrypt(
      SecretBox(
        base64Decode(ballot.ct),
        nonce: base64Decode(ballot.nonce),
        mac: Mac(base64Decode(ballot.mac)),
      ),
      secretKey: key,
      aad: utf8.encode(electionId),
    );

    if (clear.length < 2) throw const FormatException('Bad ballot.');
    final len = (clear[0] << 8) | clear[1];
    if (len > clear.length - 2) throw const FormatException('Bad ballot.');
    final json = jsonDecode(utf8.decode(clear.sublist(2, 2 + len)))
        as Map<String, dynamic>;
    if (json['e'] != electionId) {
      throw const FormatException('Ballot belongs to another election.');
    }
    return Map<String, dynamic>.from(json['v'] as Map)
        .map((k, v) => MapEntry(k, v as String));
  }

  /// Short public receipt: first 8 bytes of SHA-256(ciphertext), e.g.
  /// "9F3A-11C2-7B0D-E4A8". Anyone can recompute it from the stored ballot,
  /// but it reveals nothing about the choices.
  static Future<String> receiptFor(String ctB64) async {
    final hash = await Sha256().hash(base64Decode(ctB64));
    final hex = hash.bytes
        .take(8)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
    return [
      for (var i = 0; i < hex.length; i += 4) hex.substring(i, i + 4),
    ].join('-');
  }

  static String normalizeReceipt(String r) =>
      r.toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');
}
