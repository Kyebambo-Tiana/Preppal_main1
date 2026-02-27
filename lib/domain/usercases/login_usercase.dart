import 'package:prepal2/data/models/auth/user_model.dart';
import 'package:prepal2/domain/repositories/auth_repository.dart';

class LoginUseCase {
	// We depend on the ABSTRACT repository, not the concrete implementation.
	// This is called "Dependency Inversion" - a key Clean Architecture principle.
	final AuthRepository repository;

	LoginUseCase({required this.repository});

	// The 'call' method lets us use the class like a function:
	// e.g., await LoginUseCase(email: '...', password: '...')
	// => UserModel instead of UserEntity
	Future<UserModel> call({
		required String email,
		required String password,
	}) async {
		// You can add domain-level validation here before hitting the API.
		if (email.isEmpty || password.isEmpty) {
			throw Exception('Email and password cannot be empty');
		}

		return await repository.login(email: email, password: password);
	}
}
