import 'package:endpoint_security_checkin/src/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('automatic findings stay read-only and secure when enabled', () {
    const result = SecurityCheckResult(
      id: 'firewall',
      label: 'Firewall',
      detectedStatus: CheckStatus.enabled,
      detectedAutomatically: true,
      summary: 'Firewall enabled.',
    );

    expect(result.requiresUserConfirmation, isFalse);
    expect(result.hasPendingConfirmation, isFalse);
    expect(result.effectiveStatus, CheckStatus.enabled);
    expect(result.isSecure, isTrue);
  });

  test('manual findings stay pending until employee confirms them', () {
    const pending = SecurityCheckResult(
      id: 'screen_lock',
      label: 'Screen lock',
      detectedStatus: CheckStatus.manualReview,
      detectedAutomatically: false,
      summary: 'Needs review.',
    );

    expect(pending.requiresUserConfirmation, isTrue);
    expect(pending.hasPendingConfirmation, isTrue);
    expect(pending.effectiveStatus, CheckStatus.manualReview);
    expect(pending.isSecure, isFalse);
  });

  test('manual findings can become resolved and insecure', () {
    const result = SecurityCheckResult(
      id: 'one_password',
      label: '1Password installed',
      detectedStatus: CheckStatus.manualReview,
      reviewedStatus: CheckStatus.disabled,
      detectedAutomatically: false,
      summary: 'Needs review.',
    );

    expect(result.requiresUserConfirmation, isTrue);
    expect(result.hasPendingConfirmation, isFalse);
    expect(result.effectiveStatus, CheckStatus.disabled);
    expect(result.isInsecure, isTrue);
  });
}
