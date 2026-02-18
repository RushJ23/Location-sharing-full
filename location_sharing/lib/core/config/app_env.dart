import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration (dev/prod).
/// Load .env.local via dotenv in main(); falls back to --dart-define if not set.
class AppEnv {
  AppEnv._();

  /// Deep link used for email confirmation and magic links. Must be added to
  /// Supabase Dashboard → Authentication → URL Configuration → Redirect URLs.
  static String get authRedirectUrl =>
      kIsWeb ? '' : 'location-sharing://auth/callback';

  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL']?.trim() ??
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY']?.trim() ??
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  /// Google Maps API key (Android/iOS read from .env.local at build time; Dart can use for web).
  static String get googleMapsApiKey =>
      dotenv.env['GOOGLE_MAPS_API_KEY']?.trim() ??
      String.fromEnvironment('GOOGLE_MAPS_API_KEY', defaultValue: '');

  static bool get isProd =>
      supabaseUrl.isNotEmpty && !supabaseUrl.contains('localhost');
}
