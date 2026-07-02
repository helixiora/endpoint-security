import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../models.dart';

class SubmissionException implements Exception {
  SubmissionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SubmissionService {
  SubmissionService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _submissionTimeout = Duration(seconds: 12);
  static const _redirectStatusCodes = {301, 302, 303, 307, 308};
  static const _maxRedirects = 5;

  Future<void> submit(
    EndpointSubmission submission, {
    required String submissionEndpoint,
    required String signingSecret,
  }) async {
    if (submissionEndpoint.trim().isEmpty) {
      throw SubmissionException(
        'No submission endpoint is configured for this device.',
      );
    }

    if (signingSecret.trim().isEmpty) {
      throw SubmissionException(
        'No submission signing secret is configured for this build.',
      );
    }

    final uri = Uri.tryParse(submissionEndpoint);
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw SubmissionException(
          'The configured submission endpoint is invalid.');
    }

    final payload = jsonEncode(
      signedEnvelope(
        submission,
        signingSecret: signingSecret,
      ),
    );
    late http.Response response;
    try {
      response = await _sendFollowingRedirects(uri, payload).timeout(
        _submissionTimeout,
      );
    } on TimeoutException {
      throw SubmissionException('Submitting the report timed out.');
    } catch (error) {
      throw SubmissionException('Could not submit the report: $error');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SubmissionException(_buildFailureMessage(response));
    }

    _validateSuccessResponse(response);
  }

  Map<String, dynamic> signedEnvelope(
    EndpointSubmission submission, {
    required String signingSecret,
    DateTime? signedAt,
  }) {
    final trimmedSecret = signingSecret.trim();
    if (trimmedSecret.isEmpty) {
      throw SubmissionException(
        'No submission signing secret is configured for this build.',
      );
    }

    final signedAtUtc = (signedAt ?? DateTime.now().toUtc()).toUtc();
    final signedAtIso = signedAtUtc.toIso8601String();
    // The payload travels as an opaque JSON string and the signature covers
    // that exact string, so verification never depends on the server
    // re-serializing the payload the same way this client did.
    final payloadJson = jsonEncode(submission.toJson());
    final signature = Hmac(sha256, utf8.encode(trimmedSecret))
        .convert(utf8.encode('$signedAtIso\n$payloadJson'))
        .toString();

    return {
      'schemaVersion': 3,
      'auth': {
        'algorithm': 'HMAC-SHA256',
        'signedAtUtc': signedAtIso,
        'signature': signature,
      },
      'payloadJson': payloadJson,
    };
  }

  Future<http.Response> _sendFollowingRedirects(Uri uri, String payload) async {
    var currentUri = uri;
    var method = 'POST';

    for (var redirectCount = 0;
        redirectCount <= _maxRedirects;
        redirectCount++) {
      final response = await _sendRequest(
        currentUri,
        method: method,
        payload: method == 'GET' ? null : payload,
      );

      if (!_redirectStatusCodes.contains(response.statusCode)) {
        return response;
      }

      final location = response.headers['location'];
      if (location == null || location.trim().isEmpty) {
        return response;
      }

      if (redirectCount == _maxRedirects) {
        return response;
      }

      currentUri = currentUri.resolve(location);
      method = _redirectMethod(response.statusCode, method);
    }

    throw StateError('Redirect limit handling failed unexpectedly.');
  }

  Future<http.Response> _sendRequest(
    Uri uri, {
    required String method,
    String? payload,
  }) async {
    final request = http.Request(method, uri)
      ..headers['Accept'] = 'application/json';

    if (payload != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = payload;
    }

    final streamedResponse = await _client.send(request);
    return http.Response.fromStream(streamedResponse);
  }

  String _redirectMethod(int statusCode, String currentMethod) {
    if (statusCode == 303) {
      return 'GET';
    }

    if ((statusCode == 301 || statusCode == 302) &&
        currentMethod.toUpperCase() == 'POST') {
      return 'GET';
    }

    return currentMethod;
  }

  String _buildFailureMessage(http.Response response) {
    if (response.statusCode >= 300 && response.statusCode < 400) {
      final location = response.headers['location'];
      final locationSuffix = location == null || location.trim().isEmpty
          ? ''
          : ' Redirect target: $location';
      return 'The submission endpoint redirected the report instead of accepting it '
          '(${response.statusCode}). Check that the configured URL is the final '
          'destination, usually the deployed /exec URL.$locationSuffix';
    }

    final details = _summarizeResponseBody(response.body);
    if (details == null) {
      return 'The server rejected the report (${response.statusCode}).';
    }

    return 'The server rejected the report (${response.statusCode}): $details';
  }

  void _validateSuccessResponse(http.Response response) {
    final body = response.body.trim();
    if (body.isEmpty) {
      return;
    }

    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      throw SubmissionException(
        'The server returned an invalid success response.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw SubmissionException(
        'The server returned an invalid success response.',
      );
    }

    if (decoded['ok'] == true) {
      return;
    }

    final error = decoded['error']?.toString().trim();
    if (error == null || error.isEmpty) {
      throw SubmissionException('The server did not accept the report.');
    }

    throw SubmissionException('The server did not accept the report: $error');
  }

  String? _summarizeResponseBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final withoutTags = trimmed.replaceAll(RegExp(r'<[^>]*>'), ' ');
    final normalized = withoutTags.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return null;
    }

    const maxLength = 220;
    if (normalized.length <= maxLength) {
      return normalized;
    }

    return '${normalized.substring(0, maxLength - 1)}…';
  }
}
