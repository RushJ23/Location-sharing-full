/// Environment configuration (dev/prod).
/// Use --dart-define=SUPABASE_URL=... and SUPABASE_ANON_KEY=... or set defaults for dev.
class AppEnv {
  AppEnv._();

  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  static bool get isProd =>
      supabaseUrl.isNotEmpty && !supabaseUrl.contains('localhost');
}
