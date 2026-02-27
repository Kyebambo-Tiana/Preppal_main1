import 'package:prepal2/data/models/auth/user_model.dart';

abstract class AuthRepository {
	// Returns a UserModel on success, throws an Exception on failure.
	Future<UserModel> login({
		required String email,
		required String password,
	});

	Future<UserModel> signup({
		required String username,
		required String email,
		required String password,
		required String businessName,
	});

	// Clears saved session data.
	Future<void> logout();

	// Checks if a user session exists (for auto-login on app start).
	Future<UserModel?> getLoggedInUser();
}
