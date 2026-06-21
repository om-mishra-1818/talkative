import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/di/locator.dart';
import '../../../core/providers/theme_provider.dart';
import '../providers/user_profile_provider.dart';
import '../../../core/widgets/custom_avatar.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _profileProvider = locator<UserProfileProvider>();
  final _nameController = TextEditingController();
  final _statusController = TextEditingController();
  File? _localImage;

  @override
  void initState() {
    super.initState();
    _profileProvider.addListener(_onProfileUpdated);
    _updateControllers();
  }

  @override
  void dispose() {
    _profileProvider.removeListener(_onProfileUpdated);
    _nameController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  void _onProfileUpdated() {
    _updateControllers();
  }

  void _updateControllers() {
    if (_profileProvider.profile != null) {
      if (_nameController.text != _profileProvider.profile!.username) {
        _nameController.text = _profileProvider.profile!.username;
      }
      if (_statusController.text != _profileProvider.profile!.status) {
        _statusController.text = _profileProvider.profile!.status;
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    // Downscale/compress at pick time: a profile photo never needs to be full
    // camera resolution, and this keeps the upload (and local base64) small.
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _localImage = File(pickedFile.path);
      });
      try {
        await _profileProvider.updatePhoto(File(pickedFile.path));
        if (mounted) {
          _showSuccessPopup('Photo uploaded successfully!');
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _localImage = null; // Revert local image on failure
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload photo: $e')),
          );
        }
      }
    }
  }

  void _saveChanges() {
    if (_profileProvider.profile != null) {
      final updated = _profileProvider.profile!.copyWith(
        username: _nameController.text.trim(),
        status: _statusController.text.trim(),
      );
      _profileProvider.updateProfile(updated);
      _showSuccessPopup('Profile updated successfully!');
    }
  }

  void _showSuccessPopup(String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, color: Theme.of(context).primaryColor, size: 48),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
    
    // Auto-close after 1.5 seconds
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _profileProvider,
      builder: (context, _) {
        final profile = _profileProvider.profile;
        if (profile == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final themeProvider = context.watch<ThemeProvider>();

        return SingleChildScrollView(
          padding: const EdgeInsets.only(
            left: 24.0,
            right: 24.0,
            top: 24.0,
            bottom: 120.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    _localImage != null
                        ? Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: DecorationImage(
                                image: FileImage(_localImage!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        : CustomAvatar(
                            imageUrl: _profileProvider.localPhotoBase64 != null
                                ? 'base64:${_profileProvider.localPhotoBase64}'
                                : profile.avatarUrl.isNotEmpty
                                    ? profile.avatarUrl
                                    : 'https://ui-avatars.com/api/?name=${profile.username}',
                            radius: 60,
                          ),
                    if (_profileProvider.isLoading)
                      const Positioned.fill(child: CircularProgressIndicator())
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _statusController,
                decoration: const InputDecoration(
                  labelText: 'Custom Status',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text('Save Changes'),
              ),
              const SizedBox(height: 40),
              const Divider(),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Granular Visibility Settings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Online Status Visibility'),
                subtitle: const Text('Show others when you are online'),
                value: profile.isOnlineVisible,
                onChanged: (val) {
                  _profileProvider.updateProfile(
                    profile.copyWith(isOnlineVisible: val),
                  );
                },
              ),
              SwitchListTile(
                title: const Text('Typing Indicators'),
                subtitle: const Text('Show others when you are typing'),
                value: profile.typingIndicators,
                onChanged: (val) {
                  _profileProvider.updateProfile(
                    profile.copyWith(typingIndicators: val),
                  );
                },
              ),
              SwitchListTile(
                title: const Text('Dark Mode (Fluid Theme Morphing)'),
                subtitle: const Text('Toggle app appearance'),
                value: themeProvider.isDarkMode,
                onChanged: (val) {
                  themeProvider.toggleTheme(val);
                },
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () async {
                  await context.read<AuthProvider>().logout();
                },
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                label: const Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
