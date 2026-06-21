import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
  
  StreamSubscription? _authSubscription;
  StreamSubscription? _profileSubscription;

  UserProfileProvider() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      _profileSubscription?.cancel();
      _profile = null;
      localPhotoBase64 = null;
      notifyListeners();
      
      if (user != null) {
        _initProfileStream(user);
      }
    });
  }

  void refresh() {
    final user = FirebaseAuth.instance.currentUser;
    _profileSubscription?.cancel();
    _profile = null;
    localPhotoBase64 = null;
    notifyListeners();
    if (user != null) {
      _initProfileStream(user);
    }
  }

  void _initProfileStream(User user) {
      _profileSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((doc) async {
            if (doc.exists) {
              final prefs = await SharedPreferences.getInstance();
              localPhotoBase64 = prefs.getString('local_profile_photo_${user.uid}');
              _profile = UserProfileObject.fromJson(doc.data()!, doc.id);
              notifyListeners();
            } else {
              // Create default profile if not exists
              _profile = UserProfileObject(
                id: user.uid,
                username: user.displayName ?? 'New User',
                status: 'Available',
                avatarUrl: user.photoURL ?? '',
              );
              updateProfile(_profile!);
            }
          }, onError: (error) {
            debugPrint('Error listening to user profile: $error');
            // Set a fallback profile to prevent the UI from loading infinitely
            _profile = UserProfileObject(
              id: user.uid,
              username: user.displayName ?? user.email?.split('@').first ?? 'User',
              status: 'Available',
              avatarUrl: user.photoURL ?? '',
            );
            notifyListeners();
          });
  }

  Future<void> updateProfile(UserProfileObject newProfile) async {
    _profile = newProfile;
    notifyListeners();

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(newProfile.id)
          .set(newProfile.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating profile: $e');
    }
  }

  Future<void> updatePhoto(File imageFile) async {
    if (_profile == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Local base64 cache → instant preview on THIS device only.
      final bytes = await imageFile.readAsBytes();
      final base64String = base64Encode(bytes);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_profile_photo_${user.uid}', base64String);
      localPhotoBase64 = base64String;
      notifyListeners();

      try {
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile_photos/${user.uid}.jpg');
        await ref.putFile(
          imageFile,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        final downloadUrl = await ref.getDownloadURL();

        // Writes avatarUrl into the user's Firestore doc; every chat list /
        // contacts / chat view that reads avatarUrl picks it up automatically.
        await updateProfile(_profile!.copyWith(avatarUrl: downloadUrl));
      } catch (storageError) {
        debugPrint('Storage upload failed, falling back to base64 in Firestore: $storageError');
        // Fallback: save base64 directly to Firestore so other users can see it
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
    _profileSubscription?.cancel();
    super.dispose();
  }
}
