class ApiConstants {
  ApiConstants._();

  // ── Main Backend ───────────────────────────────────────────
  static const String baseUrl = 'https://preppal-backend-px1d.onrender.com';

  // ── ML Service (separate server) ───────────────────────────
  static const String mlBaseUrl = 'https://preppal-2mb4.onrender.com';
  static const String mlPredict = '$mlBaseUrl/api/predict';

  // ── Auth ───────────────────────────────────────────────────
  static const String authSignup = '/api/v1/auth/signup';
  static const String authLogin = '/api/v1/auth/login';
  static const String authForgotPassword = '/api/v1/auth/forgot-password';
  static const String authResetPassword = '/api/v1/auth/reset-password';

  // ── Business (verified working routes) ────────────────────
  static const String businessCreate = '/api/v1/business/create';
  // backend lists routes as `/api/v1/business` for retrieving all of a user’s
  // businesses. earlier versions attempted `/business/all` which produced
  // 404 errors and confused the client logging.
  static const String businessGetAll = '/api/v1/business';
  static String businessGetById(String id) => '/api/v1/business/$id';
  static String businessUpdate(String id) => '/api/v1/business/update/$id';
  static String businessDelete(String id) => '/api/v1/business/$id';

  // ── Inventory ──────────────────────────────────────────────
  static const String inventoryCreate = '/api/v1/inventory/create';
  static String inventoryByBusiness(String id) =>
      '/api/v1/inventory/business/$id';
  static String inventoryById(String id) => '/api/v1/inventory/$id';
  static String inventoryUpdate(String id) => '/api/v1/inventory/$id';
  static String inventoryDelete(String id) => '/api/v1/inventory/$id';

  // ── Daily Sales ────────────────────────────────────────────
  // the backend accepts both with/without trailing slash, but omit it here to
  // keep URIs consistent with other constants.
  static const String salesAll = '/api/v1/daily-sales/sales';
  static const String salesCreate = '/api/v1/daily-sales/create';
  static String salesByBusiness(String id) =>
      '/api/v1/daily-sales/business/$id';
  static String saleById(String id) => '/api/v1/daily-sales/$id';
  static String saleUpdate(String id) => '/api/v1/daily-sales/update/$id';
  static String saleDelete(String id) => '/api/v1/daily-sales/$id';

  // ── Alerts ────────────────────────────────────────────────
  static const String alertsAll = '/api/v1/alerts';
  static String alertsByBusiness(String id) => '/api/v1/alerts/business/$id';
  static String alertUpdate(String id) => '/api/v1/alerts/update/$id';
  static String alertDelete(String id) => '/api/v1/alerts/$id';

  // ── Timeouts ───────────────────────────────────────────────
  // Increased to 500 to accommodate slow backend responses/cold starts.
  static const int connectionTimeout = 500;
  static const int receiveTimeout = 500;

  // ── Network Resilience ──────────────────────────────────────
  // Number of retries after the first failed attempt.
  static const int maxNetworkRetries = 2;
  // Initial delay before retrying (exponential backoff doubles this).
  static const int retryBaseDelayMs = 1500;
}
