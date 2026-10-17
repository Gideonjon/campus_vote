import 'package:flutter/foundation.dart';

class AppConfig {
  static const appName = 'CampusVote';

  /// Your Firebase Hosting URL. Used by the mobile app to build share links.
  /// On the web build, the current site origin is used automatically.
  /// Change this after your first `firebase deploy`.
  static const webBaseUrl = 'https://campus-vote-f26fc.web.app';

  static String get publicBaseUrl => kIsWeb ? Uri.base.origin : webBaseUrl;

  static String electionLink(String electionId) =>
      '$publicBaseUrl/e/$electionId';
}
