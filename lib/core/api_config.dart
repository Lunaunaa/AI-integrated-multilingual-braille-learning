/// Central configuration for the backend API URL.
/// Defaults to 'http://localhost:8000', can be overridden via:
/// flutter run --dart-define=API_BASE_URL=https://your-api.com
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: String.fromEnvironment(
    'RESONANT_TUTOR_API_BASE',
    defaultValue: 'http://localhost:8000',
  ),
);

