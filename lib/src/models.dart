enum CheckStatus {
  enabled,
  disabled,
  unknown,
  notApplicable,
  manualReview,
}

extension CheckStatusX on CheckStatus {
  String get label => switch (this) {
        CheckStatus.enabled => 'Enabled',
        CheckStatus.disabled => 'Disabled',
        CheckStatus.unknown => 'Unknown',
        CheckStatus.notApplicable => 'Not applicable',
        CheckStatus.manualReview => 'Manual review',
      };

  String get wireValue => switch (this) {
        CheckStatus.enabled => 'enabled',
        CheckStatus.disabled => 'disabled',
        CheckStatus.unknown => 'unknown',
        CheckStatus.notApplicable => 'not_applicable',
        CheckStatus.manualReview => 'manual_review',
      };

  static CheckStatus fromWireValue(String value) => switch (value) {
        'enabled' => CheckStatus.enabled,
        'disabled' => CheckStatus.disabled,
        'not_applicable' => CheckStatus.notApplicable,
        'manual_review' => CheckStatus.manualReview,
        _ => CheckStatus.unknown,
      };
}

class SecurityCheckResult {
  const SecurityCheckResult({
    required this.id,
    required this.label,
    required this.detectedStatus,
    CheckStatus? reviewedStatus,
    required this.detectedAutomatically,
    required this.summary,
    this.details,
  }) : reviewedStatus = reviewedStatus ?? detectedStatus;

  final String id;
  final String label;
  final CheckStatus detectedStatus;
  final CheckStatus reviewedStatus;
  final bool detectedAutomatically;
  final String summary;
  final String? details;

  bool get requiresUserConfirmation =>
      detectedStatus == CheckStatus.manualReview ||
      detectedStatus == CheckStatus.unknown;

  CheckStatus get effectiveStatus =>
      requiresUserConfirmation ? reviewedStatus : detectedStatus;

  bool get hasPendingConfirmation =>
      requiresUserConfirmation &&
      (effectiveStatus == CheckStatus.manualReview ||
          effectiveStatus == CheckStatus.unknown);

  bool get isSecure => effectiveStatus == CheckStatus.enabled;

  bool get isInsecure => effectiveStatus == CheckStatus.disabled;

  bool get isInformational => effectiveStatus == CheckStatus.notApplicable;

  bool get isOverridden =>
      requiresUserConfirmation && detectedStatus != reviewedStatus;

  SecurityCheckResult copyWith({
    CheckStatus? detectedStatus,
    CheckStatus? reviewedStatus,
    bool? detectedAutomatically,
    String? summary,
    String? details,
  }) {
    return SecurityCheckResult(
      id: id,
      label: label,
      detectedStatus: detectedStatus ?? this.detectedStatus,
      reviewedStatus: reviewedStatus ?? this.reviewedStatus,
      detectedAutomatically:
          detectedAutomatically ?? this.detectedAutomatically,
      summary: summary ?? this.summary,
      details: details ?? this.details,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'detectedStatus': detectedStatus.wireValue,
      'reviewedStatus': reviewedStatus.wireValue,
      'effectiveStatus': effectiveStatus.wireValue,
      'detectedAutomatically': detectedAutomatically,
      'requiresUserConfirmation': requiresUserConfirmation,
      'hasPendingConfirmation': hasPendingConfirmation,
      'summary': summary,
      'details': details,
      'isOverridden': isOverridden,
    };
  }
}

class DeviceContext {
  const DeviceContext({
    required this.platform,
    required this.osVersion,
    required this.deviceModel,
    required this.endpointName,
    required this.deviceIdentifierLabel,
    required this.deviceIdentifier,
  });

  final String platform;
  final String osVersion;
  final String deviceModel;
  final String endpointName;
  final String deviceIdentifierLabel;
  final String deviceIdentifier;
}

class EndpointInspectionReport {
  const EndpointInspectionReport({
    required this.collectedAt,
    required this.device,
    required this.checks,
  });

  final DateTime collectedAt;
  final DeviceContext device;
  final List<SecurityCheckResult> checks;

  EndpointInspectionReport copyWith({
    DateTime? collectedAt,
    DeviceContext? device,
    List<SecurityCheckResult>? checks,
  }) {
    return EndpointInspectionReport(
      collectedAt: collectedAt ?? this.collectedAt,
      device: device ?? this.device,
      checks: checks ?? this.checks,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'collectedAtUtc': collectedAt.toUtc().toIso8601String(),
      'device': {
        'platform': device.platform,
        'osVersion': device.osVersion,
        'deviceModel': device.deviceModel,
        'detectedEndpointName': device.endpointName,
        'deviceIdentifierLabel': device.deviceIdentifierLabel,
        'deviceIdentifier': device.deviceIdentifier,
      },
      'checks': checks.map((check) => check.toJson()).toList(),
    };
  }
}

class StoredProfile {
  const StoredProfile({
    required this.ownerName,
    required this.ownerEmail,
    required this.endpointName,
  });

  final String ownerName;
  final String ownerEmail;
  final String endpointName;
}

class EndpointSubmission {
  const EndpointSubmission({
    required this.organization,
    required this.ownerName,
    required this.ownerEmail,
    required this.endpointName,
    required this.notes,
    required this.report,
    required this.submittedAt,
  });

  final String organization;
  final String ownerName;
  final String ownerEmail;
  final String endpointName;
  final String notes;
  final EndpointInspectionReport report;
  final DateTime submittedAt;

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': 2,
      'organization': organization,
      'submittedAtUtc': submittedAt.toUtc().toIso8601String(),
      'collectedAtUtc': report.collectedAt.toUtc().toIso8601String(),
      'owner': {
        'name': ownerName,
        'email': ownerEmail,
      },
      'endpoint': {
        'submittedName': endpointName,
        'detectedName': report.device.endpointName,
        'platform': report.device.platform,
        'osVersion': report.device.osVersion,
        'deviceModel': report.device.deviceModel,
        'deviceIdentifierLabel': report.device.deviceIdentifierLabel,
        'deviceIdentifier': report.device.deviceIdentifier,
      },
      'notes': notes,
      'checks': report.checks.map((check) => check.toJson()).toList(),
    };
  }
}
