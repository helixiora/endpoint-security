import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class StoredProfileRepository {
  static const _ownerNameKey = 'owner_name';
  static const _ownerEmailKey = 'owner_email';
  static const _endpointNameKey = 'endpoint_name';

  Future<StoredProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    return StoredProfile(
      ownerName: prefs.getString(_ownerNameKey) ?? '',
      ownerEmail: prefs.getString(_ownerEmailKey) ?? '',
      endpointName: prefs.getString(_endpointNameKey) ?? '',
    );
  }

  Future<void> save(StoredProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ownerNameKey, profile.ownerName);
    await prefs.setString(_ownerEmailKey, profile.ownerEmail);
    await prefs.setString(_endpointNameKey, profile.endpointName);
  }
}

class EndpointSettingsRepository {
  static const _submissionEndpointKey = 'submission_endpoint';

  Future<String> loadSubmissionEndpoint() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_submissionEndpointKey)?.trim() ?? '';
  }

  Future<void> saveSubmissionEndpoint(String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = endpoint.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(_submissionEndpointKey);
      return;
    }

    await prefs.setString(_submissionEndpointKey, trimmed);
  }
}
