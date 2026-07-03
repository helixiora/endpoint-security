import 'dart:async';

import 'package:endpoint_security_checkin/src/app.dart';
import 'package:endpoint_security_checkin/src/inspector/endpoint_inspector.dart';
import 'package:endpoint_security_checkin/src/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeInspector extends EndpointInspector {
  @override
  Future<EndpointInspectionReport> inspect() async {
    return _fakeReport();
  }
}

class _DelayedInspector extends EndpointInspector {
  final completer = Completer<EndpointInspectionReport>();

  @override
  Future<EndpointInspectionReport> inspect() => completer.future;
}

EndpointInspectionReport _fakeReport() {
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

  Future<void> completeIdentity(WidgetTester tester) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Owner name'),
      'Jane Doe',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Owner email'),
      'jane@example.com',
    );

    await tester.tap(find.text('Continue to scan'));
    await tester.pumpAndSettle();
  }

  Future<void> openReviewStep(WidgetTester tester) async {
    await completeIdentity(tester);
    await tester.tap(find.text('Review 1 open item'));
    await tester.pumpAndSettle();
  }

  testWidgets('guides through identity before showing inspected checks',
      (tester) async {
    await pumpScreen(tester);

    expect(find.text('Complete endpoint check-in'), findsOneWidget);
    expect(find.text('Confirm who owns this endpoint'), findsOneWidget);

    // The detected endpoint name pre-fills the form.
    expect(find.widgetWithText(TextFormField, 'janes-mbp'), findsOneWidget);

    await completeIdentity(tester);

    expect(find.text('Detected device'), findsOneWidget);
    expect(find.textContaining('C02TEST123'), findsWidgets);

    await tester.tap(find.text('Review 1 open item'));
    await tester.pumpAndSettle();

    expect(find.text('Hard disk encryption'), findsOneWidget);
    expect(find.text('Endpoint malware protection / EDR'), findsOneWidget);
  });

  testWidgets('ignores late inspection results after disposal', (tester) async {
    final inspector = _DelayedInspector();

    await tester.pumpWidget(
      MaterialApp(
        home: CheckInScreen(inspector: inspector),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    inspector.completer.complete(_fakeReport());
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('review dialog blocks submission while confirmations pend',
      (tester) async {
    await pumpScreen(tester);
    await openReviewStep(tester);

    await tester.tap(find.text('Submit').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review check-in').last);
    await tester.pumpAndSettle();

    expect(find.text('Check-in summary'), findsOneWidget);
    expect(find.textContaining('(confirmation required)'), findsOneWidget);
    // Without a destination, secret, and confirmed checks there is no
    // Submit action, only Cancel and Copy JSON.
    expect(find.widgetWithText(FilledButton, 'Submit check-in'), findsNothing);
    expect(find.text('Copy JSON'), findsOneWidget);
  });

  testWidgets('employee confirmation resolves a manual-review check',
      (tester) async {
    await pumpScreen(tester);
    await openReviewStep(tester);

    await tester.tap(find.byKey(const ValueKey('endpoint_protection:enabled')));
    await tester.pumpAndSettle();

    // Both checks now report as compliant.
    expect(find.text('Ready to attest.'), findsNWidgets(2));
    expect(find.text('Continue to submit'), findsOneWidget);
  });
}
