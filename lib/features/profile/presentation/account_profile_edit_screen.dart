import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../../storage/storage_repository.dart';

/// Herkes için hesap profili: ad-soyad + fotoğraf (kamera/galeri).
/// Usta dükkânı alanları [ArtisanProfileEditScreen] üzerinden kalır.
class AccountProfileEditScreen extends ConsumerStatefulWidget {
  const AccountProfileEditScreen({super.key});

  @override
  ConsumerState<AccountProfileEditScreen> createState() =>
      _AccountProfileEditScreenState();
}

class _AccountProfileEditScreenState
    extends ConsumerState<AccountProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController? _name;
  String? _photoUrl;
  bool _saving = false;
  bool _uploading = false;
  bool _seeded = false;

  @override
  void dispose() {
    _name?.dispose();
    super.dispose();
  }

  void _seedIfNeeded() {
    if (_seeded) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    _name = TextEditingController(text: user.displayName);
    _photoUrl = user.profilePhotoUrl;
    _seeded = true;
  }

  Future<ImageSource?> _chooseSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final palette = context.palette;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_camera_outlined,
                    color: palette.primary),
                title: const Text('Kamera ile çek'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library_outlined,
                    color: palette.primary),
                title: const Text('Galeriden seç'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickPhoto() async {
    if (_uploading || _saving) return;
    final source = await _chooseSource();
    if (source == null || !mounted) return;

    final XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: source,
        preferredCameraDevice: source == ImageSource.camera
            ? CameraDevice.front
            : CameraDevice.rear,
        maxWidth: AppConstants.imagePickMaxWidth,
        imageQuality: AppConstants.imagePickImageQuality,
      );
    } catch (_) {
      if (mounted) {
        context.showError(source == ImageSource.camera
            ? 'Kamera açılamadı. İzinleri kontrol edin.'
            : 'Görsel seçilemedi.');
      }
      return;
    }
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > AppConstants.maxPhotoSizeBytes) {
      if (mounted) context.showError('Görsel 5 MB\'dan küçük olmalı.');
      return;
    }
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    setState(() => _uploading = true);
    try {
      final handle = await ref.read(storageRepositoryProvider).uploadImage(
            pathHint: 'profile/$uid',
            bytes: bytes,
          );
      if (mounted) setState(() => _photoUrl = handle);
    } catch (_) {
      if (mounted) {
        context.showError(
            'Fotoğraf yüklenemedi. Bağlantınızı kontrol edip tekrar deneyin.');
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _uploading) return;
    final nameCtrl = _name;
    if (nameCtrl == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name = Validators.normalizeDisplayName(nameCtrl.text);
    final nameErr = Validators.displayName(name);
    if (nameErr != null) {
      context.showError(nameErr);
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).updateUserProfile(
            displayName: name,
            profilePhotoUrl: _photoUrl,
          );
      if (!mounted) return;
      context.showSuccess('Profil kaydedildi.');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      context.showError(e is AuthException
          ? e.message
          : 'Kaydedilemedi. Bağlantınızı kontrol edip tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _seedIfNeeded();

    final user = ref.watch(currentUserProvider);
    if (user == null || _name == null) {
      return const Scaffold(
        body: Center(child: Text('Oturum bulunamadı.')),
      );
    }

    final theme = Theme.of(context);
    final palette = context.palette;
    final name = _name!.text.trim();
    final initials =
        name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();

    return Scaffold(
      appBar: const GradientAppBar(
        title: 'Profili düzenle',
        icon: Icons.person_outline,
      ),
      body: ResponsiveCenter(
        maxWidth: 520,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.border, width: 2),
                      ),
                      child: ClipOval(
                        child: SizedBox(
                          width: 104,
                          height: 104,
                          child: _photoUrl != null
                              ? AppImage(handle: _photoUrl)
                              : Container(
                                  color: palette.primaryContainer,
                                  alignment: Alignment.center,
                                  child: Text(
                                    initials,
                                    style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w800,
                                      color: palette.primary,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    if (_uploading)
                      const Positioned.fill(
                        child: ClipOval(
                          child: ColoredBox(
                            color: Colors.black38,
                            child: Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Material(
                        color: theme.colorScheme.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _uploading ? null : _pickPhoto,
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.camera_alt,
                                size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton.icon(
                  onPressed: _uploading ? null : _pickPhoto,
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: Text(
                    _photoUrl == null ? 'Fotoğraf ekle' : 'Fotoğrafı değiştir',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Ad soyad', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                maxLength: AppConstants.maxDisplayNameLength,
                validator: Validators.displayName,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person_outline),
                  helperText: "Harf, rakam, boşluk ve . ' -",
                ),
              ),
              const SizedBox(height: 8),
              Text(
                user.hasArtisanProfile
                    ? 'Bu ad ve fotoğraf hesabınızda ve sohbetlerde görünür. '
                        'Dükkân (meslek, bölge, takvim) için Usta dükkânı → '
                        'Vitrin düzenle kullanın.'
                    : 'Bu ad ve fotoğraf ilanlarınızda ve sohbetlerde görünür.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: (_saving || _uploading) ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
