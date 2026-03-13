import 'package:flutter/material.dart';
import 'package:prepal2/presentation/providers/daily_sales_provider.dart';
import 'package:prepal2/presentation/providers/dashboard_provider.dart';
import 'package:prepal2/presentation/providers/forecast_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Core
import 'package:prepal2/core/di/service_locator.dart';

// Data layer
import 'package:prepal2/data/repositories/auth_repository_impl.dart';
import 'package:prepal2/data/repositories/inventory_repository_impl.dart';

// Domain layer
import 'package:prepal2/domain/usercases/login_usercase.dart';
import 'package:prepal2/domain/usercases/signup_usercase.dart';
import 'package:prepal2/domain/usecases/inventory_usecases.dart';

// Presentation
import 'package:prepal2/presentation/providers/auth_provider.dart';
import 'package:prepal2/presentation/providers/business_provider.dart';
import 'package:prepal2/presentation/providers/inventory_provider.dart';
import 'package:prepal2/presentation/screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sharedPreferences = await SharedPreferences.getInstance();

  // Initialize service locator (ApiClient + all datasources)
  await setupServiceLocator();

  // ── Auth chain
  // Uses the real API datasource from service locator
  final authRepository = AuthRepositoryImpl(
    remoteDataSource: serviceLocator.authRemoteDataSource,
    sharedPreferences: sharedPreferences,
  );
  final loginUseCase = LoginUseCase(repository: authRepository);
  final signupUseCase = SignupUseCase(repository: authRepository);

  // ── Inventory chain
  // Uses real remote DS now
  final inventoryDataSource = serviceLocator.inventoryRemoteDataSource;
  final inventoryRepository = InventoryRepositoryImpl(
    remoteDataSource: inventoryDataSource,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            loginUseCase: loginUseCase,
            signupUseCase: signupUseCase,
            authRepository: authRepository,
          ),
        ),
        ChangeNotifierProvider(create: (_) => BusinessProvider()),
        // ✅ NEW — DashboardProvider added here
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(
          create: (_) => InventoryProvider(
            getAllProducts: GetAllProductsUseCase(
              repository: inventoryRepository,
            ),
            addProduct: AddProductUseCase(repository: inventoryRepository),
            updateProduct: UpdateProductUseCase(
              repository: inventoryRepository,
            ),
            deleteProduct: DeleteProductUseCase(
              repository: inventoryRepository,
            ),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              ForecastProvider(serviceLocator.forecastRemoteDataSource),
        ),
        ChangeNotifierProvider(create: (_) => DailySalesProvider()),
      ],
      child: const PrepPalApp(),
    ),
  );
}

class PrepPalApp extends StatelessWidget {
  const PrepPalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PrepPal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD32F2F),
          primary: const Color(0xFFD32F2F),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD32F2F),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
