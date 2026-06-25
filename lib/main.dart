import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/storage/local_db.dart';
import 'core/constants/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/signup_screen.dart';
import 'features/chat/providers/chat_provider.dart';
import 'features/chat/screens/home_screen.dart';
import 'core/di/locator.dart';
import 'core/services/cleanup_service.dart';
import 'core/network/supabase_realtime_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupLocator();
  
  // Clean up old audio files
  CleanupService.cleanTemporaryAudioFiles();


  // Initialize Local Isar Database
  await locator<LocalDb>().init();

  // Initialize Supabase (Must be done manually by user with their keys)
  try {
    await Supabase.initialize(
      url: 'https://pbyimnmxqxhhzgwqzuzd.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBieWltbm14cXhoaHpnd3F6dXpkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE4MzY1MjQsImV4cCI6MjA5NzQxMjUyNH0.sBPY-mDqfPkFs2pl_3W16dm_cpySlrmlEAC6qSsHcK4',
    );
  } catch (e) {
    debugPrint(
      'Supabase init error: $e. Please replace YOUR_SUPABASE_URL_HERE and YOUR_SUPABASE_ANON_KEY_HERE with actual keys.',
    );
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: const TalkativeApp(),
    ),
  );
}

class TalkativeApp extends StatelessWidget {
  const TalkativeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'Talkative',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  bool showLogin = true;

  void toggleView() {
    setState(() {
      showLogin = !showLogin;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAuthenticated) return;

    if (state == AppLifecycleState.resumed) {
      authProvider.updateStatus('Online');
    } else if (state == AppLifecycleState.paused || 
               state == AppLifecycleState.detached || 
               state == AppLifecycleState.hidden || 
               state == AppLifecycleState.inactive) {
      // High-priority background network push to toggle cloud presence flag to offline
      authProvider.updateStatus('Offline');
      
      // Instantly wipe presence token from any active chat room
      try {
        locator<SupabaseRealtimeService>().leaveCurrentChat();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (authProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (authProvider.isAuthenticated) {
      return const HomeScreen();
    } else {
      if (showLogin) {
        return LoginScreen(onToggle: toggleView);
      } else {
        return SignupScreen(onToggle: toggleView);
      }
    }
  }
}
