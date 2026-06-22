class AppConfig {
  static const appName = 'Helixiora Endpoint Security';

  static const organizationName = String.fromEnvironment(
    'ORGANIZATION_NAME',
    defaultValue: 'Helixiora',
  );

  static const appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '0.1.0-dev',
  );

  static const submissionEndpoint = String.fromEnvironment(
    'SUBMISSION_ENDPOINT',
    defaultValue: '',
  );

  static const submissionSecret = String.fromEnvironment(
    'SUBMISSION_SECRET',
    defaultValue: '',
  );

  static String get displayVersion {
    final trimmed = appVersion.trim();
    return trimmed.isEmpty ? 'unknown' : trimmed;
  }

  static String get windowTitle => '$appName ($displayVersion)';
}
