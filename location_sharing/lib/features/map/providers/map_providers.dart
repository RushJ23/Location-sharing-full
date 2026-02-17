import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/always_share_repository.dart';

final alwaysShareRepositoryProvider = Provider<AlwaysShareRepository>((ref) {
  return AlwaysShareRepository();
});
