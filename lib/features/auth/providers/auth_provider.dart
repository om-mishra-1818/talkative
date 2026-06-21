import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthProvider with ChangeNotifier {
  FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  User? _user;
  String? _username;
  bool _isLoading = true;

  bool _isSigningUp = false;

  bool get isAuthenticated => _user != null && !_isSigningUp;
  String? get username => _username;
  String? get currentUserId => _user?.uid;
  bool get isLoading => _isLoading;

  AuthProvider() {
    if (_auth == null) {
      _isLoading = false;
      return;
    }
    _auth!.authStateChanges().listen((User? user) async {
      _user = user;
      if (user != null) {
        try {
          final doc = await _firestore!.collection('users').doc(user.uid).get();
          if (doc.exists) {
            _username = doc.data()?['username'];
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
    if (_auth == null)
      return "Firebase is not configured! Please run flutterfire configure.";
    try {
      final userCredential = await _auth!.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Update status to online
      if (userCredential.user != null) {
        await _firestore!
            .collection('users')
            .doc(userCredential.user!.uid)
            .update({
              'isOnline': true,
              'lastSeen': FieldValue.serverTimestamp(),
            });
      }
      return null; // Success
    } on FirebaseAuthException catch (e) {
      debugPrint("Login auth error: ${e.message}");
      return e.message;
    } catch (e) {
      debugPrint("Login error: $e");
      return e.toString();
    }
  }

  Future<String?> signup(String username, String email, String password) async {
    if (_auth == null)
      return "Firebase is not configured! Please run flutterfire configure.";
    try {
      _isSigningUp = true;
      notifyListeners();

      final userCredential = await _auth!.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final trimmedUsername = username.trim();
      
      // Now that the user is created and authenticated, we can query Firestore
      final usernameQuery = await _firestore!
          .collection('users')
          .where('username', isEqualTo: trimmedUsername)
          .get();
          
      if (usernameQuery.docs.isNotEmpty) {
        // Username is taken, rollback user creation
        await userCredential.user?.delete();
        _isSigningUp = false;
        notifyListeners();
        return "Username already exists. Please choose another.";
      }

      if (userCredential.user != null) {
        await _firestore!.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'username': trimmedUsername,
          'email': email.trim(),
          'avatarUrl':
              'https://ui-avatars.com/api/?name=${Uri.encodeComponent(username)}&background=random',
          'isOnline': true,
          'lastSeen': FieldValue.serverTimestamp(),
        });
        _isSigningUp = false;
        notifyListeners();
        return null; // Success
      }
      _isSigningUp = false;
      notifyListeners();
      return "An unknown error occurred.";
    } on FirebaseAuthException catch (e) {
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
    if (_auth == null) return;
    if (_user != null) {
      try {
        await _firestore!.collection('users').doc(_user!.uid).update({
          'isOnline': false,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint("Error updating offline status: $e");
      }
    }
    await _auth!.signOut();
  }

  Future<void> updateStatus(String statusStr) async {
    if (_user == null || _firestore == null) return;
    try {
      final isOnline = statusStr == 'Online' || statusStr == 'Typing' || statusStr == 'Recording Voice' || statusStr == 'On Call';
      final updateData = <String, dynamic>{
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      };
      
      // Do not overwrite the user's custom status text when merely going online or offline.
      if (statusStr != 'Online' && statusStr != 'Offline') {
        updateData['status'] = statusStr;
      }
      
      await _firestore!.collection('users').doc(_user!.uid).update(updateData);
    } catch (e) {
      debugPrint("Error updating status: $e");
    }
  }
}
