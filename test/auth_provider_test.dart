import 'package:flutter_test/flutter_test.dart';
import 'package:prepal2/data/models/auth/user_model.dart';
import 'package:prepal2/domain/repositories/auth_repository.dart';
import 'package:prepal2/domain/usercases/login_usercase.dart';
import 'package:prepal2/domain/usercases/signup_usercase.dart';
import 'package:prepal2/presentation/providers/auth_provider.dart';
import 'package:prepal2/core/di/service_locator.dart';
import 'package:prepal2/data/datasources/auth_remote_datasource.dart';

// simple fake implementations to satisfy dependencies
class _FakeAuthRepository implements AuthRepository {
  @override
  Future<UserModel?> getLoggedInUser() async => null;

  @override
  Future<UserModel> login({required String email, required String password}) {
    throw UnimplementedError();
  }

  @override
  Future<UserModel> signup({
    required String username,
    required String email,
    required String password,
    required String businessName,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {}
}

class _FakeRemote implements AuthRemoteDataSource {
  bool called = false;
  String? lastOtp;

  @override
  Future<void> verifyEmail({required String otp}) async {
    called = true;
    lastOtp = otp;
  }

  // all other methods are unused in these tests
  @override
  Future<Map<String, dynamic>> register({required String email, required String username, required String password}) {
    throw UnimplementedError();
  }

  @override
  Future<String> login({required String email, required String password}) {
    throw UnimplementedError();
  }

  @override
  Future<void> resendVerificationEmail(String email) {
    throw UnimplementedError();
  }

  @override
  Future<void> forgotPassword(String email) {
    throw UnimplementedError();
  }

  @override
  Future<void> resetPassword({required String email, required String password}) {
    throw UnimplementedError();
  }
}

void main() {
  late AuthProvider provider;
  late _FakeRemote fakeRemote;

  setUp(() {
    final repo = _FakeAuthRepository();
    provider = AuthProvider(
      loginUseCase: LoginUseCase(repository: repo),
      signupUseCase: SignupUseCase(repository: repo),
      authRepository: repo,
    );

    fakeRemote = _FakeRemote();
    // override service locator
    serviceLocator.authRemoteDataSourceForTest = fakeRemote;
  });

  test('verifyEmail fails when OTP is wrong length and does not call API', () async {
    final result = await provider.verifyEmail(otp: '12');
    expect(result, isFalse);
    expect(provider.errorMessage, contains('4 digits'));
    expect(provider.status, AuthStatus.error);
    expect(fakeRemote.called, isFalse);
  });

  test('verifyEmail forwards call when OTP length is exactly 4', () async {
    final result = await provider.verifyEmail(otp: '1234');
    expect(result, isTrue);
    expect(provider.status, AuthStatus.authenticated);
    expect(fakeRemote.called, isTrue);
    expect(fakeRemote.lastOtp, '1234');
  });
}
