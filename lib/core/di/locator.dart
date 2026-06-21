import 'package:get_it/get_it.dart';
import '../../features/chat/providers/user_profile_provider.dart';
import '../storage/local_db.dart';
import '../network/supabase_realtime_service.dart';

final locator = GetIt.instance;

void setupLocator() {
  locator.registerLazySingleton<UserProfileProvider>(
    () => UserProfileProvider(),
  );

  locator.registerLazySingleton<LocalDb>(() => LocalDb());
  locator.registerLazySingleton<SupabaseRealtimeService>(
      () => SupabaseRealtimeService());
}
