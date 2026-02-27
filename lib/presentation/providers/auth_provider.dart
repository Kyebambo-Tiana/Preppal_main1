import 'package:flutter/material.dart';
import 'package:prepal2/core/di/service_locator.dart';
import 'package:prepal2/data/models/auth/user_model.dart';
import 'package:prepal2/domain/repositories/auth_repository.dart';
import 'package:prepal2/domain/usercases/login_usercase.dart';
import 'package:prepal2/domain/usercases/signup_usercase.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final LoginUseCase loginUseCase;
  final SignupUseCase signupUseCase;
  final AuthRepository authRepository;

  AuthStatus _status = AuthStatus.initial;
  UserModel? _currentUser;
  String? _errorMessage;
  String? _userEmail; // stored for verification screen

  AuthProvider({
    required this.loginUseCase,
    required this.signupUseCase,
    required this.authRepository,
  }) {
    _resolveSession();
  }

  AuthStatus get status => _status;
  UserModel? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  String? get userEmail => _userEmail;
  bool get isLoading => _status == AuthStatus.loading;

  // ── Session Resolution ──────────────────────────────────────
  Future<void> _resolveSession() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      final user = await authRepository.getLoggedInUser();
      if (user != null) {
        _currentUser = user;
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (_) {
      _status = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  // ── Login ───────────────────────────────────────────────────
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await loginUseCase(email: email, password: password);
      _userEmail = email;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _clean(e);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  // ── Signup ──────────────────────────────────────────────────
  Future<bool> signup({
    required String username,
    required String email,
    required String password,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // signupUseCase requires businessName — pass empty string
      // (business setup happens on BusinessDetailsScreen after verification)
      _currentUser = await signupUseCase(
        username: username,
        email: email,
        password: password,
        confirmPassword: password, // already validated in UI
        businessName: '',
      );
      _userEmail = email;
      // Not authenticated yet — email verification required
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _clean(e);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  // ── Email Verification ──────────────────────────────────────
  Future<bool> verifyEmail({required String otp}) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    // enforce exact length before hitting network
    if (otp.length != 4) {
      _errorMessage = 'Verification code must be 4 digits';
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }

    try {
      // Call API: POST /auth/verify-email { token: otp }
      final authDataSource = serviceLocator.authRemoteDataSource;
      await authDataSource.verifyEmail(otp: otp);

      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _clean(e);
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  // ── Resend Verification 
  Future<bool> resendVerificationEmail(String email) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final authDataSource = serviceLocator.authRemoteDataSource;
      await authDataSource.resendVerificationEmail(email);

      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _clean(e);
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  // ── Logout ──────────────────────────────────────────────────
  Future<void> logout() async {
    await authRepository.logout();
    _currentUser = null;
    _userEmail = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _clean(Object e) =>
      e.toString().replaceAll('Exception: ', '');
}
