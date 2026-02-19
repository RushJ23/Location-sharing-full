/// Push notifications removed. Contacts are notified by email instead.
/// Kept as stub for compatibility; these calls are no-ops.

Future<void> registerFcmAndSaveToken(String userId) async {
  // No-op: push notifications disabled
}

void setupFcmHandlers(void Function(String?) onNotificationTap) {
  // No-op: push notifications disabled
}
