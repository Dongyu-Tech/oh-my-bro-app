import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/in_app_update_service.dart';

final inAppUpdateServiceProvider = Provider<InAppUpdateService>(
  (ref) => InAppUpdateService(),
);
