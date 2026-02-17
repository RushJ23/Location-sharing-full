import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/contact_repository.dart';
import '../../../data/repositories/contact_request_repository.dart';
import '../domain/contact.dart';
import '../domain/contact_request.dart';

final contactRequestRepositoryProvider = Provider<ContactRequestRepository>((ref) {
  return ContactRequestRepository();
});

final contactRepositoryProvider = Provider<ContactRepository>((ref) {
  return ContactRepository();
});

final incomingRequestsProvider =
    FutureProvider.family<List<ContactRequest>, String>((ref, userId) async {
  return ref.watch(contactRequestRepositoryProvider).getIncoming(userId);
});

final outgoingRequestsProvider =
    FutureProvider.family<List<ContactRequest>, String>((ref, userId) async {
  return ref.watch(contactRequestRepositoryProvider).getOutgoing(userId);
});

final contactsProvider = FutureProvider.family<List<Contact>, String>((ref, userId) async {
  return ref.watch(contactRepositoryProvider).getContacts(userId);
});
