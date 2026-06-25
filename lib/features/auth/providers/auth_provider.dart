import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? _user;
  String? _username;
  bool _isLoading = true;
  bool _isSigningUp = false;

  bool get isAuthenticated => _user != null && !_isSigningUp;
  String? get username => _username;
  String? get currentUserId => _user?.id;
  bool get isLoading => _isLoading;

  StreamSubscription<AuthState>? _authStateSubscription;

  AuthProvider() {
    _initAuthListener();
  }

  void _initAuthListener() {
    _authStateSubscription = _supabase.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;
      
      _user = session?.user;
      
      if (_user != null) {
        try {
          final response = await _supabase
              .from('users')
              .select('username')
              .eq('id', _user!.id)
              .maybeSingle();
              
          if (response != null) {
            _username = response['username'];
          }
        } catch (e) {
          debugPrint("Error fetching user data: $e");
        }
      } else {
        _username = null;
      }
      
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<String?> login(String email, String password) async {
    try {
      final AuthResponse res = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      // Update status to online
      if (res.user != null) {
        await _supabase.from('users').update({
          'isOnline': true,
          'lastSeen': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', res.user!.id);
      }
      return null; // Success
    } on AuthException catch (e) {
      debugPrint("Login auth error: ${e.message}");
      return e.message;
    } catch (e) {
      debugPrint("Login error: $e");
      return e.toString();
    }
  }

  Future<String?> signup(String username, String email, String password) async {
    try {
      _isSigningUp = true;
      notifyListeners();

      final trimmedUsername = username.trim();
      
      // Check if username exists
      final usernameQuery = await _supabase
          .from('users')
          .select('id')
          .eq('username', trimmedUsername)
          .maybeSingle();
          
      if (usernameQuery != null) {
        _isSigningUp = false;
        notifyListeners();
        return "Username already exists. Please choose another.";
      }

      final AuthResponse res = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
      );

      if (res.user != null) {
        await _supabase.from('users').insert({
          'id': res.user!.id,
          'username': trimmedUsername,
          'email': email.trim(),
          'avatarUrl': 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(username)}&background=random',
          'isOnline': true,
          'lastSeen': DateTime.now().toUtc().toIso8601String(),
        });
        
        _isSigningUp = false;
        notifyListeners();
        return null; // Success
      }
      
      _isSigningUp = false;
      notifyListeners();
      return "An unknown error occurred.";
    } on AuthException catch (e) {
      _isSigningUp = false;
      notifyListeners();
      debugPrint("Signup auth error: ${e.message}");
      return e.message;
    } catch (e) {
      _isSigningUp = false;
      notifyListeners();
      debugPrint("Signup error: $e");
      return e.toString();
    }
  }

  Future<void> logout() async {
    if (_user != null) {
      try {
        await _supabase.from('users').update({
          'isOnline': false,
          'lastSeen': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', _user!.id);
      } catch (e) {
        debugPrint("Error updating offline status: $e");
      }
    }
    await _supabase.auth.signOut();
  }

  Future<void> updateStatus(String statusStr) async {
    if (_user == null) return;
    try {
      final isOnline = statusStr == 'Online' || statusStr == 'Typing' || statusStr == 'Recording Voice' || statusStr == 'On Call';
      final updateData = <String, dynamic>{
        'isOnline': isOnline,
        'lastSeen': DateTime.now().toUtc().toIso8601String(),
      };
      
      if (statusStr != 'Online' && statusStr != 'Offline') {
        updateData['status'] = statusStr;
      }
      
      await _supabase.from('users').update(updateData).eq('id', _user!.id);
    } catch (e) {
      debugPrint("Error updating status: $e");
    }
  }
  
  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }
}
