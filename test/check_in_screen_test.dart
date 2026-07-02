import 'package:endpoint_security_checkin/src/app.dart';
import 'package:endpoint_security_checkin/src/inspector/endpoint_inspector.dart';
import 'package:endpoint_security_checkin/src/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeInspector extends EndpointInspector {
  @override
  Future<EndpointInspectionReport> inspect() async {
    return EndpointInspectionReport(
      collectedAt: DateTime.utc(2026, 6, 1, 12),
      device: const DeviceContext(
        platform: 'macOS',
        osVersion: '15.5.0',
        deviceModel: 'MacBookPro18,3',
        endpointName: 'janes-mbp',
        deviceIdentifierLabel: 'Serial number',
        deviceIdentifier: 'C02TEST123',
      ),
      checks: const [
        SecurityCheckResult(
          id: 'disk_encryption',
          label: 'Hard disk encryption',
          detectedStatus: CheckStatus.enabled,
          detectedAutomatically: true,
          summary: 'FileVault is enabled.',
        ),
        SecurityCheckResult(
          id: 'endpoint_protection',
          label: 'Endpoint malware protection / EDR',
          detectedStatus: CheckStatus.manualReview,
          detectedAutomatically: false,
          summary: 'Review required.',
        ),
      ],
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    // Tall enough that the lazily built check list renders fully, but
    // narrower than the 1180px desktop layout breakpoint.
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: CheckInScreen(inspector: _FakeInspector()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders inspected checks and device context', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Hard disk encryption'), findsOneWidget);
    expect(find.text('Endpoint malware protection / EDR'), findsOneWidget);
    expect(find.textContaining('C02TEST123'), findsWidgets);

    // The detected endpoint name pre-fills the form.
    expect(find.widgetWithText(TextFormField, 'janes-mbp'), findsOneWidget);
  });

  testWidgets('review dialog blocks submission while confirmations pend',
      (tester) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Owner name'),
      'Jane Doe',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Owner email'),
      'jane@example.com',
    );

    await tester.ensureVisible(find.text('Review check-in'));
    await tester.tap(find.text('Review check-in'));
    await tester.pumpAndSettle();

    expect(find.text('Review submission'), findsOneWidget);
    expect(find.textContaining('(confirmation required)'), findsOneWidget);
    // Without a destination, secret, and confirmed checks there is no
    // Submit action, only Cancel and Copy JSON.
    expect(find.widgetWithText(FilledButton, 'Submit'), findsNothing);
    expect(find.text('Copy JSON'), findsOneWidget);
  });

  testWidgets('employee confirmation resolves a manual-review check',
      (tester) async {
    await pumpScreen(tester);

    await tester.ensureVisible(find.text('Select status'));
    await tester.tap(find.text('Select status'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enabled').last);
    await tester.pumpAndSettle();

    // Both checks now report as compliant.
    expect(find.text('Compliant and secure.'), findsNWidgets(2));
  });
}
