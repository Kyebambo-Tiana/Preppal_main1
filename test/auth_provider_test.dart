import 'package:flutter_test/flutter_test.dart';
import 'package:prepal2/data/models/auth/user_model.dart';
import 'package:prepal2/domain/repositories/auth_repository.dart';
import 'package:prepal2/domain/usercases/login_usercase.dart';
import 'package:prepal2/domain/usercases/signup_usercase.dart';
import 'package:prepal2/presentation/providers/auth_provider.dart';

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

void main() {
  late AuthProvider provider;

  setUp(() {
    final repo = _FakeAuthRepository();
    provider = AuthProvider(
      loginUseCase: LoginUseCase(repository: repo),
      signupUseCase: SignupUseCase(repository: repo),
      authRepository: repo,
    );
  });

  test(
    'initial status resolves to unauthenticated when no user exists',
    () async {
      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(provider.status, AuthStatus.unauthenticated);
    },
  );
}
