import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prepal2/core/di/service_locator.dart';
import 'package:prepal2/data/datasources/auth_remote_datasource.dart';
import 'package:prepal2/data/models/auth/user_model.dart';
import 'package:prepal2/domain/repositories/auth_repository.dart';

const String _kUserKey = 'auth_user';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final SharedPreferences sharedPreferences;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.sharedPreferences,
  });

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    // Step 1: Get token from API
    // API returns: { success, accessToken: { token } }
    final token = await remoteDataSource.login(
      email: email,
      password: password,
    );

    // Step 2: Build UserModel from what we know
    // Login endpoint does not return user object — only token.
    // We decode the JWT to extract id, email, role from its payload.
    final payload = _decodeJwt(token);
    final user = UserModel(
      id: payload['id'] as String? ?? '',
      email: payload['email'] as String? ?? email,
      username: email.split('@')[0], // best guess until profile is available
      role: payload['role'] as String?,
      token: token,
    );

    // Step 3: Cache user locally
    await _saveUser(user);
    return user;
  }

  @override
  Future<UserModel> signup({
    required String username,
    required String email,
    required String password,
    required String businessName,
  }) async {
    // API returns user data inside "data" key
    // { id, email, username, role, accountStatus, isEmailVerified }
    final userData = await remoteDataSource.register(
      username: username,
      email: email,
      password: password,
    );

    final user = UserModel.fromJson(userData);
    await _saveUser(user);
    return user;
  }

  @override
  Future<void> logout() async {
    await serviceLocator.apiClient.clearAll();
    await sharedPreferences.remove(_kUserKey);
  }

  @override
  Future<void> forgotPassword(String email) {
    return remoteDataSource.forgotPassword(email);
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String password,
  }) {
    return remoteDataSource.resetPassword(email: email, password: password);
  }

  @override
  Future<UserModel?> getLoggedInUser() async {
    // Check token exists
    final token = serviceLocator.apiClient.getAuthToken();
    if (token == null) return null;

    // Check token not expired
    if (_isTokenExpired(token)) {
      await logout();
      return null;
    }

    // Return cached user
    final jsonStr = sharedPreferences.getString(_kUserKey);
    if (jsonStr == null) return null;

    try {
      return UserModel.fromJson(json.decode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveUser(UserModel user) async {
    await sharedPreferences.setString(_kUserKey, json.encode(user.toJson()));
  }

  // Decodes JWT payload (middle part) without any external package
  Map<String, dynamic> _decodeJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};

      String payload = parts[1];
      // Fix base64 padding
      switch (payload.length % 4) {
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
      }

      final decoded = utf8.decode(base64Url.decode(payload));
      return json.decode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  bool _isTokenExpired(String token) {
    try {
      final payload = _decodeJwt(token);
      final exp = payload['exp'] as int?;
      if (exp == null) return false;
      return DateTime.now().isAfter(
        DateTime.fromMillisecondsSinceEpoch(exp * 1000),
      );
    } catch (_) {
      return true;
    }
  }
}
