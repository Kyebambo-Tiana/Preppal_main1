import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:prepal2/core/network/api_client.dart';
import 'package:prepal2/core/network/api_constants.dart';

/// Abstract interface — all auth API calls go through here
abstract class AuthRemoteDataSource {
  /// POST /api/v1/auth/signup
  /// Returns { success, data: { id, email, username, role, accountStatus, isEmailVerified } }
  Future<Map<String, dynamic>> register({
    required String email,
    required String username,
    required String password,
  });

  /// POST /api/v1/auth/login
  /// Returns { success, accessToken: { token } }
  Future<String> login({required String email, required String password});

  /// POST /api/v1/auth/forgot-password
  Future<void> forgotPassword(String email);

  /// POST /api/v1/auth/reset-password
  Future<void> resetPassword({required String email, required String password});
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient _apiClient;

  AuthRemoteDataSourceImpl(this._apiClient);

  Map<String, dynamic> _tryParseJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String _extractMessage(Map<String, dynamic> body, String fallback) {
    final direct = body['message'];
    if (direct is String && direct.trim().isNotEmpty) {
      return direct;
    }

    final error = body['error'];
    if (error is String && error.trim().isNotEmpty) {
      return error;
    }

    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) {
      final first = errors.first;
      if (first is String && first.trim().isNotEmpty) return first;
      if (first is Map<String, dynamic>) {
        final firstMessage = first['message'];
        if (firstMessage is String && firstMessage.trim().isNotEmpty) {
          return firstMessage;
        }
      }
    }

    return fallback;
  }

  String? _extractToken(Map<String, dynamic> body) {
    final directToken = body['token'];
    if (directToken is String && directToken.isNotEmpty) return directToken;

    final accessToken = body['accessToken'];
    if (accessToken is String && accessToken.isNotEmpty) return accessToken;
    if (accessToken is Map<String, dynamic>) {
      final nested = accessToken['token'];
      if (nested is String && nested.isNotEmpty) return nested;
    }

    final data = body['data'];
    if (data is Map<String, dynamic>) {
      final dataToken = data['token'];
      if (dataToken is String && dataToken.isNotEmpty) return dataToken;
      final dataAccessToken = data['accessToken'];
      if (dataAccessToken is String && dataAccessToken.isNotEmpty) {
        return dataAccessToken;
      }
      if (dataAccessToken is Map<String, dynamic>) {
        final nested = dataAccessToken['token'];
        if (nested is String && nested.isNotEmpty) return nested;
      }
    }

    return null;
  }

  @override
  Future<Map<String, dynamic>> register({
    required String email,
    required String username,
    required String password,
  }) async {
    late final http.Response response;
    try {
      response = await _apiClient.post(
        ApiConstants.authSignup,
        body: {'email': email, 'username': username, 'password': password},
      );
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('network timeout') ||
          message.contains('network error')) {
        throw Exception(
          'Sign up timed out while waiting for the server response. '
          'Your internet may be fine - the server could be busy or waking up. '
          'Please wait 30-60 seconds and try again. If this repeats, try '
          'logging in because your account may have already been created.',
        );
      }
      rethrow;
    }

    final body = _tryParseJson(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      // API wraps user data inside "data" key
      // { success: true, data: { id, email, username, role, ... } }
      final data = body['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }
      throw Exception(
        'Registration succeeded but user data was missing in response.',
      );
    } else {
      final rawMessage = _extractMessage(body, 'Registration failed');
      print('Signup failed. Raw body: $body');

      final normalized = rawMessage.toString().toLowerCase();

      // Handle common unique constraint responses across backend variants.
      if (normalized.contains('validation error') ||
          normalized.contains('already exists') ||
          normalized.contains('already taken') ||
          normalized.contains('duplicate')) {
        throw Exception(
          'This account already exists (username or email already used). '
          'Try logging in, or use a different username/email.',
        );
      }
      throw Exception(rawMessage);
    }
  }

  @override
  Future<String> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.authLogin,
      body: {'email': email, 'password': password},
    );

    final body = _tryParseJson(response.body);

    if (response.statusCode == 200) {
      // Accept multiple token response shapes across backend versions.
      final token = _extractToken(body);
      if (token == null) {
        throw Exception(
          'Login succeeded but no auth token was returned by the server.',
        );
      }

      // Save token into ApiClient for all future requests
      await _apiClient.setAuthToken(token);

      return token;
    } else {
      final message = _extractMessage(body, 'Login failed');
      throw Exception(message);
    }
  }

  @override
  Future<void> forgotPassword(String email) async {
    final response = await _apiClient.post(
      ApiConstants.authForgotPassword,
      body: {'email': email},
    );

    if (response.statusCode != 200) {
      final body = _tryParseJson(response.body);
      throw Exception(_extractMessage(body, 'Request failed'));
    }
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.authResetPassword,
      body: {'email': email, 'password': password},
    );

    if (response.statusCode != 200) {
      final body = _tryParseJson(response.body);
      throw Exception(_extractMessage(body, 'Password reset failed'));
    }
  }
}
