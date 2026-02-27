import 'package:prepal2/data/models/auth/user_model.dart';
import 'package:prepal2/domain/repositories/auth_repository.dart';

class SignupUseCase {
  final AuthRepository repository;

  SignupUseCase({required this.repository});

  Future<UserModel> call({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
    required String businessName,
  }) async {
    // validation (business rules go here)
    if (username.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty ) {
      throw Exception('All fields are required');
    }

    if (password.length < 8) {
      throw Exception('Password must be at least 8 characters');
    }

    // Backend requires strict password complexity
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasLowercase = password.contains(RegExp(r'[a-z]'));
    final hasDigits = password.contains(RegExp(r'[0-9]'));
    final hasSpecialCharacters = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    if (!hasUppercase || !hasLowercase || !hasDigits || !hasSpecialCharacters) {
      throw Exception('Password must contain at least 1 uppercase, 1 lowercase, 1 number, and 1 special character');
    }

    if (password != confirmPassword) {
      throw Exception('Passwords do not match');
    }

    return await repository.signup(
      username: username,
      email: email,
      password: password,
      businessName: businessName,
    );
  }
}
