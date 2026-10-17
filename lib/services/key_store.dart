import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Small on-device storage.
/// - The host's key share for each election (never uploaded).
/// - The voter's receipt for each election.
class KeyStore {
  static Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  static Future<void> saveHostShare(String electionId, List<int> share) async {
    final p = await _prefs;
    await p.setString('hostkey_$electionId', base64Encode(share));
  }

  static Future<List<int>?> loadHostShare(String electionId) async {
    final p = await _prefs;
    final s = p.getString('hostkey_$electionId');
    return s == null ? null : base64Decode(s);
  }

  static Future<void> saveReceipt(String electionId, String receipt) async {
    final p = await _prefs;
    await p.setString('receipt_$electionId', receipt);
  }

  static Future<String?> loadReceipt(String electionId) async {
    final p = await _prefs;
    return p.getString('receipt_$electionId');
  }
}
