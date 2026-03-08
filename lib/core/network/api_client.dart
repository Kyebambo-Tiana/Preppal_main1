import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'api_constants.dart';

/// HTTP Client that handles token injection, logging, and error handling.
/// All datasources use this — never call http.Client directly.
class ApiClient {
  final http.Client httpClient;
  late SharedPreferences _prefs;
  String? _authToken;
  String? _businessId; // cached after business load

  ApiClient({http.Client? httpClient})
    : httpClient = httpClient ?? http.Client();

  /// Call this once in main() before using ApiClient
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _authToken = _prefs.getString('auth_token');
    _businessId = _prefs.getString('business_id');
  }

  // ── Token Management ────────────────────────────────────────

  Future<void> setAuthToken(String token) async {
    _authToken = token;
    await _prefs.setString('auth_token', token);
  }

  String? getAuthToken() => _authToken;

  Future<void> clearAuthToken() async {
    _authToken = null;
    await _prefs.remove('auth_token');
  }

  bool isAuthenticated() => _authToken != null;

  // ── Business ID Management ──────────────────────────────────

  Future<void> setBusinessId(String id) async {
    _businessId = id;
    await _prefs.setString('business_id', id);
  }

  String? getBusinessId() => _businessId;

  Future<void> clearAll() async {
    _authToken = null;
    _businessId = null;
    await _prefs.remove('auth_token');
    await _prefs.remove('business_id');
  }

  // ── Headers ─────────────────────────────────────────────────

  Map<String, String> _getHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  // ── HTTP Methods ────────────────────────────────────────────

  Future<http.Response> _sendWithRetry(
    Future<http.Response> Function() request, {
    required String requestName,
  }) async {
    var attempt = 0;

    while (true) {
      try {
        final response = await request().timeout(
          const Duration(seconds: ApiConstants.connectionTimeout),
        );
        _log(response);
        return response;
      } catch (e) {
        final canRetry =
            attempt < ApiConstants.maxNetworkRetries &&
            _isRetryableNetworkIssue(e);

        if (!canRetry) {
          if (e is TimeoutException) {
            throw Exception(
              'Network timeout. Please check your connection and try again.',
            );
          }

          if (_isRetryableNetworkIssue(e)) {
            throw Exception(
              'Network error. Please check your connection and try again.',
            );
          }

          rethrow;
        }

        final delayMs = ApiConstants.retryBaseDelayMs * (1 << attempt);
        attempt++;
        print(
          'Retrying $requestName (attempt ${attempt + 1}/${ApiConstants.maxNetworkRetries + 1})...',
        );
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
  }

  bool _isRetryableNetworkIssue(Object error) {
    if (error is TimeoutException || error is http.ClientException) {
      return true;
    }

    final message = error.toString().toLowerCase();
    return message.contains('xmlhttprequest') ||
        message.contains('network request failed') ||
        message.contains('failed to fetch') ||
        message.contains('connection closed');
  }

  Future<http.Response> get(String endpoint) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    return _sendWithRetry(
      () => httpClient.get(url, headers: _getHeaders()),
      requestName: 'GET $endpoint',
    );
  }

  Future<http.Response> post(
    String endpoint, {
    required Map<String, dynamic> body,
  }) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    return _sendWithRetry(
      () =>
          httpClient.post(url, headers: _getHeaders(), body: jsonEncode(body)),
      requestName: 'POST $endpoint',
    );
  }

  Future<http.Response> put(
    String endpoint, {
    required Map<String, dynamic> body,
  }) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    return _sendWithRetry(
      () => httpClient.put(url, headers: _getHeaders(), body: jsonEncode(body)),
      requestName: 'PUT $endpoint',
    );
  }

  Future<http.Response> delete(String endpoint) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    return _sendWithRetry(
      () => httpClient.delete(url, headers: _getHeaders()),
      requestName: 'DELETE $endpoint',
    );
  }

  /// POST to the ML service (different base URL, no auth needed)
  Future<http.Response> mlPost(
    String url, {
    required Map<String, dynamic> body,
  }) async {
    final uri = Uri.parse(url);
    return _sendWithRetry(
      () => httpClient.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
      requestName: 'POST $url',
    );
  }

  void _log(http.Response response) {
    // the backend returns 404 when there are no businesses yet. this is a
    // normal condition that we already handle upstream, so we avoid spamming
    // the console with a red error indicator for that particular path.
    final path = response.request?.url.path ?? '';
    if (response.statusCode == 404 && path.contains('/business')) {
      print('API 404 (no business): ${response.request?.url}');
      return;
    }

    if (response.statusCode >= 400) {
      print('API Error ${response.statusCode}: ${response.body}');
    } else {
      print('API ${response.statusCode}: ${response.request?.url}');
    }
  }
}
