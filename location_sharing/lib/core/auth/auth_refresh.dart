import 'package:flutter/foundation.dart';

/// Notifier for GoRouter refresh when auth state changes.
class AuthRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}
