/// BACKEND API INTEGRATION GUIDE
/// =============================
/// 
/// This file documents how to integrate the new backend API datasources
/// into your existing repositories and providers.
///
/// CURRENT ARCHITECTURE:
/// ├── API Client (api_client.dart) - HTTP wrapper with auth token management
/// ├── Remote Data Sources - Concrete API endpoints
/// │   ├── AuthRemoteDataSource - Authentication endpoints
/// │   ├── BusinessRemoteDataSource - Business management endpoints
/// │   └── DailySalesRemoteDataSource - Sales tracking endpoints
/// ├── Repositories - Business logic + data source combination
/// ├── Use Cases - Specific business operations
/// └── Providers - Flutter state management
///
/// ============================================================================
/// STEP 5: UPDATE AUTH REPOSITORY
/// ============================================================================
/// 
/// Current file: lib/data/repositories/auth_repository_impl.dart
/// 
/// The repository should now:
/// 1. Accept AuthRemoteDataSource in constructor
/// 2. Call remote datasource methods instead of local storage
/// 3. Save token to SharedPreferences for persistence
///
/// EXAMPLE:
/// --------
/// class AuthRepositoryImpl implements AuthRepository {
///   final AuthRemoteDataSource remoteDataSource;
///   final SharedPreferences sharedPreferences;
///
///   AuthRepositoryImpl({
///     required this.remoteDataSource,
///     required this.sharedPreferences,
///   });
///
///   @override
///   Future<bool> register({
///     required String email,
///     required String username,
///     required String password,
///   }) async {
///     try {
///       final user = await remoteDataSource.register(
///         email: email,
///         username: username,
///         password: password,
///       );
///       // Save user data locally
///       await sharedPreferences.setString('user', jsonEncode(user));
///       return true;
///     } catch (e) {
///       rethrow;
///     }
///   }
///
///   @override
///   Future<bool> login({
///     required String email,
///     required String password,
///   }) async {
///     try {
///       final result = await remoteDataSource.login(
///         email: email,
///         password: password,
///       );
///       // Save token and user data
///       await sharedPreferences.setString('auth_token', result['token']);
///       await sharedPreferences.setString(
///         'user',
///         jsonEncode(result['user']),
///       );
///       return true;
///     } catch (e) {
///       rethrow;
///     }
///   }
/// }
///
/// ============================================================================
/// STEP 6: UPDATE BUSINESS REPOSITORY (Create if doesn't exist)
/// ============================================================================
///
/// New file: lib/data/repositories/business_repository_impl.dart
///
/// class BusinessRepositoryImpl implements BusinessRepository {
///   final BusinessRemoteDataSource remoteDataSource;
///
///   BusinessRepositoryImpl(this.remoteDataSource);
///
///   @override
///   Future<void> registerBusiness({
///     required String businessName,
///     required String businessType,
///     required String contactAddress,
///     required String contactNumber,
///     String? website,
///   }) async {
///     try {
///       await remoteDataSource.registerBusiness(
///         businessName: businessName,
///         businessType: businessType,
///         contactAddress: contactAddress,
///         contactNumber: contactNumber,
///         website: website,
///       );
///     } catch (e) {
///       rethrow;
///     }
///   }
/// }
///
/// ============================================================================
/// STEP 7: UPDATE MAIN.DART INITIALIZATION
/// ============================================================================
///
/// Add this to main() before runApp():
///
/// import 'package:prepal2/core/di/service_locator.dart';
///
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   final sharedPreferences = await SharedPreferences.getInstance();
///   
///   // Initialize service locator (DI container)
///   setupServiceLocator();
///   
///   runApp(const MyApp());
/// }
///
/// ============================================================================
/// STEP 8: USING IN PROVIDERS
/// ============================================================================
///
/// Example in AuthProvider:
///
/// class AuthProvider extends ChangeNotifier {
///   final LoginUseCase _loginUseCase;
///   final ApiClient _apiClient;
///
///   AuthProvider({
///     required LoginUseCase loginUseCase,
///     required ApiClient apiClient,
///   })  : _loginUseCase = loginUseCase,
///         _apiClient = apiClient;
///
///   Future<void> login(String email, String password) async {
///     try {
///       _isLoading = true;
///       notifyListeners();
///       
///       await _loginUseCase(
///         email: email,
///         password: password,
///       );
///       
///       // Token is automatically set in ApiClient by the datasource
///       _isLoading = false;
///       notifyListeners();
///     } catch (e) {
///       _errorMessage = e.toString();
///       _isLoading = false;
///       notifyListeners();
///       rethrow;
///     }
///   }
/// }
///
/// ============================================================================
/// IMPORTANT NOTES
/// ============================================================================
///
/// 1. AUTH TOKEN MANAGEMENT:
///    - After successful login, the token is automatically stored in ApiClient
///    - All subsequent requests include the Authorization header
///    - On logout, call: ApiClient().clearAuthToken()
///
/// 2. ERROR HANDLING:
///    - All HTTP errors are wrapped in Exception
///    - Catch and handle appropriately in providers
///    - Show user-friendly error messages in UI
///
/// 3. SHARED PREFERENCES:
///    - Use to persist user data and preferences
///    - BUT the actual data sync comes from API
///    - Local cache = offline fallback
///
/// 4. TESTING THE CONNECTION:
///    - Print response bodies to debug
///    - Check status codes (200 = OK, 201 = Created)
///    - Use Postman to test backend before UI integration
///
/// 5. NEXT STEPS:
///    - Create Business Repository (link Business datasource)
///    - Create Sales Repository (link Sales datasource)
///    - Update use cases to call repositories that call datasources
///    - Update providers to use repositories via use cases
/// ============================================================================
