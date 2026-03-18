import 'package:endpoint_security_checkin/src/models.dart';
import 'package:endpoint_security_checkin/src/submission/submission_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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
    );

    expect(
      visited,
      equals([
        'POST https://example.com/exec',
        'GET https://script.googleusercontent.com/macros/echo?id=1',
      ]),
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
