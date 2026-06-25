import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../models/user_profile.dart';

class UserProfileProvider extends ChangeNotifier {
  UserProfileObject? _profile;
  UserProfileObject? get profile => _profile;

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  String? localPhotoBase64;
  
  StreamSubscription<AuthState>? _authSubscription;
  RealtimeChannel? _profileSubscription;
  final SupabaseClient _supabase = Supabase.instance.client;

  UserProfileProvider() {
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      final Session? session = data.session;
      _profileSubscription?.unsubscribe();
      _profile = null;
      localPhotoBase64 = null;
      notifyListeners();
      
      if (session?.user != null) {
        _initProfileStream(session!.user!);
      }
    });
  }

  void refresh() {
    final user = _supabase.auth.currentUser;
    _profileSubscription?.unsubscribe();
    _profile = null;
    localPhotoBase64 = null;
    notifyListeners();
    if (user != null) {
      _initProfileStream(user);
    }
  }

  Future<void> _fetchAndSetProfile(User user) async {
    try {
      final doc = await _supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();
          
      if (doc != null) {
        final prefs = await SharedPreferences.getInstance();
        localPhotoBase64 = prefs.getString('local_profile_photo_${user.id}');
        _profile = UserProfileObject.fromJson(doc, doc['id']);
        notifyListeners();
      } else {
        // Create default profile if not exists
        _profile = UserProfileObject(
          id: user.id,
          username: user.userMetadata?['full_name'] ?? 'New User',
          status: 'Available',
          avatarUrl: '',
        );
        updateProfile(_profile!);
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      _profile = UserProfileObject(
        id: user.id,
        username: user.email?.split('@').first ?? 'User',
        status: 'Available',
        avatarUrl: '',
      );
      notifyListeners();
    }
  }

  void _initProfileStream(User user) {
      _fetchAndSetProfile(user);
      
      _profileSubscription = _supabase.channel('public:users:id=eq.${user.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'users',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: user.id,
            ),
            callback: (payload) {
              if (payload.newRecord.isNotEmpty) {
                _profile = UserProfileObject.fromJson(payload.newRecord, payload.newRecord['id']);
                notifyListeners();
              }
            },
          )
          .subscribe();
  }

  Future<void> updateProfile(UserProfileObject newProfile) async {
    _profile = newProfile;
    notifyListeners();

    try {
      await _supabase
          .from('users')
          .upsert(newProfile.toJson());
    } catch (e) {
      debugPrint('Error updating profile: $e');
    }
  }

  Future<void> updatePhoto(File imageFile) async {
    if (_profile == null) return;

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Local base64 cache → instant preview on THIS device only.
      final bytes = await imageFile.readAsBytes();
      final base64String = base64Encode(bytes);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_profile_photo_${user.id}', base64String);
      localPhotoBase64 = base64String;
      notifyListeners();

      try {
        final filePath = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _supabase.storage.from('avatars').upload(
          filePath,
          imageFile,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
        final downloadUrl = _supabase.storage.from('avatars').getPublicUrl(filePath);

        // Writes avatarUrl into the user's Supabase doc; every chat list /
        // contacts / chat view that reads avatarUrl picks it up automatically.
        await updateProfile(_profile!.copyWith(avatarUrl: downloadUrl));
      } catch (storageError) {
        debugPrint('Storage upload failed, falling back to base64 in Supabase: $storageError');
        // Fallback: save base64 directly to Supabase so other users can see it
        await updateProfile(_profile!.copyWith(avatarUrl: 'base64:$base64String'));
      }
    } catch (e) {
      debugPrint('Error uploading photo: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  @override
  void dispose() {
    _authSubscription?.cancel();
    _profileSubscription?.unsubscribe();
    super.dispose();
  }
}
