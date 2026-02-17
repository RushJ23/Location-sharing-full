import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration (dev/prod).
/// Load .env.local via dotenv in main(); falls back to --dart-define if not set.
class AppEnv {
  AppEnv._();

  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL']?.trim() ??
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY']?.trim() ??
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  static bool get isProd =>
      supabaseUrl.isNotEmpty && !supabaseUrl.contains('localhost');
}
