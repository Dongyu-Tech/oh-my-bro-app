import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/auth_service.dart';
import '../models/auth_user_model.dart';

/// Defaults to [NoopAuthService]. Override in main.dart when wiring a real
/// auth provider (Google Sign-In, OAuth, Supabase, etc).
final authServiceProvider = Provider<AuthService>((ref) => NoopAuthService());

/// Reactive current-user stream. UI reads this to switch between signed-in
/// and signed-out states.
final currentUserProvider = StreamProvider<AuthUserModel?>((ref) {
  final service = ref.watch(authServiceProvider);
  return service.userChanges;
});
