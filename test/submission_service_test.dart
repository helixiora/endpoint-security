import 'package:endpoint_security_checkin/src/models.dart';
import 'package:endpoint_security_checkin/src/submission/submission_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';

void main() {
  test('SubmissionService follows Apps Script style redirects', () async {
    final visited = <String>[];
    final client = MockClient((request) async {
      visited.add('${request.method} ${request.url}');

      if (request.method == 'POST' &&
          request.url == Uri.parse('https://example.com/exec')) {
        return http.Response(
          '',
          302,
          headers: {
            'location': 'https://script.googleusercontent.com/macros/echo?id=1',
          },
        );
      }

      if (request.method == 'GET' &&
          request.url ==
              Uri.parse(
                'https://script.googleusercontent.com/macros/echo?id=1',
              )) {
        return http.Response('{"ok":true}', 200);
      }

      fail('Unexpected request: ${request.method} ${request.url}');
    });

    final service = SubmissionService(client: client);
    await service.submit(
      _sampleSubmission(),
      submissionEndpoint: 'https://example.com/exec',
      signingSecret: 'test-shared-secret',
    );

    expect(
      visited,
      equals([
        'POST https://example.com/exec',
        'GET https://script.googleusercontent.com/macros/echo?id=1',
      ]),
    );
  });

  test('SubmissionService signs the payload envelope', () {
    final service = SubmissionService();
    final signedAt = DateTime.utc(2026, 3, 17, 9, 1);
    final envelope = service.signedEnvelope(
      _sampleSubmission(),
      signingSecret: 'test-shared-secret',
      signedAt: signedAt,
    );

    final payloadJson = envelope['payloadJson'] as String;
    final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
    final expectedSignature = Hmac(sha256, utf8.encode('test-shared-secret'))
        .convert(
          utf8.encode('${signedAt.toIso8601String()}\n$payloadJson'),
        )
        .toString();

    expect(envelope['schemaVersion'], 3);
    expect(envelope['auth'], {
      'algorithm': 'HMAC-SHA256',
      'signedAtUtc': signedAt.toIso8601String(),
      'signature': expectedSignature,
    });
    expect(payload['owner'], {'name': 'Jane Doe', 'email': 'jane@example.com'});
    expect(payload['schemaVersion'], 2);
    expect(payload.containsKey('report'), isFalse);
    expect(payload['collectedAtUtc'], isNotNull);
  });

  test('SubmissionService rejects ok false success responses', () async {
    final service = SubmissionService(
      client: MockClient(
        (_) async => http.Response(
          '{"ok":false,"error":"Invalid envelope signature."}',
          200,
        ),
      ),
    );

    await expectLater(
      service.submit(
        _sampleSubmission(),
        submissionEndpoint: 'https://example.com/exec',
        signingSecret: 'test-shared-secret',
      ),
      throwsA(
        isA<SubmissionException>().having(
          (error) => error.message,
          'message',
          contains('Invalid envelope signature.'),
        ),
      ),
    );
  });

  test('SubmissionService requires a signing secret', () async {
    final service =
        SubmissionService(client: MockClient((_) async => fail('')));

    await expectLater(
      service.submit(
        _sampleSubmission(),
        submissionEndpoint: 'https://example.com/exec',
        signingSecret: '',
      ),
      throwsA(
        isA<SubmissionException>().having(
          (error) => error.message,
          'message',
          contains('No submission signing secret'),
        ),
      ),
    );
  });
}

EndpointSubmission _sampleSubmission() {
  return EndpointSubmission(
    organization: 'Helixiora',
    ownerName: 'Jane Doe',
    ownerEmail: 'jane@example.com',
    endpointName: 'jane-macbook',
    notes: '',
    submittedAt: DateTime.utc(2026, 3, 17, 9),
    report: EndpointInspectionReport(
      collectedAt: DateTime.utc(2026, 3, 17, 9),
      device: const DeviceContext(
        platform: 'macOS',
        osVersion: '14.7',
        deviceModel: 'MacBook Pro',
        endpointName: 'jane-macbook',
        deviceIdentifierLabel: 'Serial number',
        deviceIdentifier: 'C02ABCDE1234',
      ),
      checks: const [
        SecurityCheckResult(
          id: 'disk_encryption',
          label: 'Hard disk encryption',
          detectedStatus: CheckStatus.enabled,
          detectedAutomatically: true,
          summary: 'FileVault is enabled.',
        ),
      ],
    ),
  );
}
