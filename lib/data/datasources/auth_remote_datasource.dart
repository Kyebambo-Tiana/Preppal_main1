import 'dart:convert';
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
  Future<String> login({
    required String email,
    required String password,
  });

  /// POST /api/v1/auth/verify-email
  /// Body: { token: "OTP_CODE" }
  Future<void> verifyEmail({required String otp});

  /// POST /api/v1/auth/resend-verification
  /// Body: { email }
  Future<void> resendVerificationEmail(String email);

  /// POST /api/v1/auth/forgot-password
  Future<void> forgotPassword(String email);

  /// POST /api/v1/auth/reset-password
  Future<void> resetPassword({
    required String email,
    required String password,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient _apiClient;

  AuthRemoteDataSourceImpl(this._apiClient);

  @override
  Future<Map<String, dynamic>> register({
    required String email,
    required String username,
    required String password,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.authSignup,
      body: {
        'email': email,
        'username': username,
        'password': password,
      },
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 || response.statusCode == 201) {
      // API wraps user data inside "data" key
      // { success: true, data: { id, email, username, role, ... } }
      return body['data'] as Map<String, dynamic>;
    } else {
      final rawMessage = body['message'] ?? 'Registration failed';
      print('Signup failed. Raw body: $body');
      
      // The backend returns a generic "Validation error" when a unique constraint fails
      if (rawMessage.toString().contains('Validation error')) {
        throw Exception(
            'This Username is already taken! 🛑\n\nThe backend requires every username to be completely unique. Please change your username to something else and try again.');
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
      body: {
        'email': email,
        'password': password,
      },
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      // API returns: { success: true, accessToken: { token: "eyJ..." } }
      final token = body['accessToken']['token'] as String;

      // Save token into ApiClient for all future requests
      await _apiClient.setAuthToken(token);

      return token;
    } else {
      final message = body['message'] ?? 'Login failed';
      throw Exception(message);
    }
  }

  @override
  Future<void> verifyEmail({required String otp}) async {
    // guard against invalid length locally (API expects 4-digit codes)
    if (otp.length != 4) {
      throw Exception('OTP must be exactly 4 digits');
    }

    final response = await _apiClient.post(
      ApiConstants.authVerifyEmail,
      body: {'token': otp}, // API expects field named "token"
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Email verification failed');
    }
  }

  @override
  Future<void> resendVerificationEmail(String email) async {
    final response = await _apiClient.post(
      ApiConstants.authResendVerification,
      body: {'email': email},
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Could not resend verification');
    }
  }

  @override
  Future<void> forgotPassword(String email) async {
    final response = await _apiClient.post(
      ApiConstants.authForgotPassword,
      body: {'email': email},
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Request failed');
    }
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.authResetPassword,
      body: {
        'email': email,
        'password': password,
      },
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Password reset failed');
    }
  }
}
