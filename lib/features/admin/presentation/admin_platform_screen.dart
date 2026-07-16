import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../../auth/application/auth_controller.dart';
import '../../storage/storage_repository.dart';
import '../data/admin_providers.dart';
import '../data/admin_runtime_config_repository.dart';
import 'admin_chrome.dart';

/// Platform kimliği: marka, destek, mağaza linkleri, duyuru bandı.
class AdminPlatformScreen extends ConsumerStatefulWidget {
  const AdminPlatformScreen({super.key});

  @override
  ConsumerState<AdminPlatformScreen> createState() =>
      _AdminPlatformScreenState();
}

class _AdminPlatformScreenState extends ConsumerState<AdminPlatformScreen> {
  bool _busy = false;
  bool _seeded = false;

  final _appName = TextEditingController();
  final _tagline = TextEditingController();
  final _logoUrl = TextEditingController();
  final _about = TextEditingController();
  final _supportEmail = TextEditingController();
  final _supportPhone = TextEditingController();
  final _play = TextEditingController();
  final _appStore = TextEditingController();
  final _web = TextEditingController();
  final _annTitle = TextEditingController();
  final _annBody = TextEditingController();
  final _annCta = TextEditingController();
  final _annCtaUrl = TextEditingController();
  bool _annEnabled = false;

  @override
  void dispose() {
    for (final c in [
      _appName,
      _tagline,
      _logoUrl,
      _about,
      _supportEmail,
      _supportPhone,
      _play,
      _appStore,
      _web,
      _annTitle,
      _annBody,
      _annCta,
      _annCtaUrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _seed(AdminRuntimeConfig c) {
    if (_seeded) return;
    _seeded = true;
    _appName.text = c.appDisplayName ?? '';
    _tagline.text = c.tagline ?? '';
    _logoUrl.text = c.logoUrl ?? '';
    _about.text = c.aboutShort ?? '';
    _supportEmail.text = c.supportEmail ?? '';
    _supportPhone.text = c.supportPhone ?? '';
    _play.text = c.playStoreUrl ?? '';
    _appStore.text = c.appStoreUrl ?? '';
    _web.text = c.websiteUrl ?? '';
    _annTitle.text = c.announcementTitle ?? '';
    _annBody.text = c.announcementBody ?? '';
    _annCta.text = c.announcementCtaLabel ?? '';
    _annCtaUrl.text = c.announcementCtaUrl ?? '';
    _annEnabled = c.announcementEnabled;
  }

  Future<void> _uploadLogo() async {
    final can = ref.read(adminCapabilitiesProvider).allows('config.manage');
    if (!can) {
      context.showError('config.manage yetkisi yok.');
      return;
    }
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 90,
      );
    } catch (_) {
      if (mounted) context.showError('Görsel seçilemedi.');
      return;
    }
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > AppConstants.maxPhotoSizeBytes) {
      if (mounted) context.showError('Logo 5 MB altı olmalı.');
      return;
    }
    setState(() => _busy = true);
    try {
      // Storage: platform/{adminUid}/… — kural: admin claim + kendi uid.
      final url = await ref.read(storageRepositoryProvider).uploadImage(
            pathHint: 'platform/$uid',
            bytes: bytes,
          );
      _logoUrl.text = url;
      await ref.read(adminRuntimeConfigRepositoryProvider).update({
        'logoUrl': url,
      });
      if (!mounted) return;
      context.showSuccess('Logo yüklendi ve kaydedildi.');
    } catch (_) {
      if (!mounted) return;
      context.showError(
          'Logo yüklenemedi. Storage kuralı deploy edildi mi?');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final can = ref.read(adminCapabilitiesProvider).allows('config.manage');
    if (!can) {
      context.showError('config.manage yetkisi yok (superadmin).');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(adminRuntimeConfigRepositoryProvider).update({
        'appDisplayName': _appName.text.trim().isEmpty ? null : _appName.text,
        'tagline': _tagline.text.trim().isEmpty ? null : _tagline.text,
        'logoUrl': _logoUrl.text.trim().isEmpty ? null : _logoUrl.text,
        'aboutShort': _about.text.trim().isEmpty ? null : _about.text,
        'supportEmail':
            _supportEmail.text.trim().isEmpty ? null : _supportEmail.text,
        'supportPhone':
            _supportPhone.text.trim().isEmpty ? null : _supportPhone.text,
        'playStoreUrl': _play.text.trim().isEmpty ? null : _play.text,
        'appStoreUrl': _appStore.text.trim().isEmpty ? null : _appStore.text,
        'websiteUrl': _web.text.trim().isEmpty ? null : _web.text,
        'announcementEnabled': _annEnabled,
        'announcementTitle':
            _annTitle.text.trim().isEmpty ? null : _annTitle.text,
        'announcementBody':
            _annBody.text.trim().isEmpty ? null : _annBody.text,
        'announcementCtaLabel':
            _annCta.text.trim().isEmpty ? null : _annCta.text,
        'announcementCtaUrl':
            _annCtaUrl.text.trim().isEmpty ? null : _annCtaUrl.text,
      });
      if (!mounted) return;
      context.showSuccess('Platform ayarları kaydedildi.');
    } catch (_) {
      if (!mounted) return;
      context.showError('Kaydedilemedi (CF deploy / yetki).');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final can = ref.watch(adminCapabilitiesProvider).allows('config.manage');
    final cfgAsync = ref.watch(adminRuntimeConfigProvider);

    return Scaffold(
      backgroundColor: AdminChrome.surface,
      appBar: AdminChrome.pageHeader(
        context: context,
        title: 'Platform & marka',
        icon: Icons.storefront_outlined,
        subtitle: 'İsim, logo URL, destek, duyuru bandı',
        actions: [
          FilledButton.icon(
            onPressed: (!can || _busy) ? null : _save,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: const Text('Kaydet'),
          ),
        ],
      ),
      body: cfgAsync.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(message: 'Config okunamadı.'),
        data: (cfg) {
          _seed(cfg);
          return ResponsiveCenter(
            maxWidth: 720,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            child: ListView(
              children: [
                if (!can)
                  Card(
                    color: palette.warningSurface,
                    child: const ListTile(
                      leading: Icon(Icons.lock_outline),
                      title: Text('Salt okunur'),
                      subtitle: Text(
                          'Düzenlemek için superadmin + config.manage gerekir.'),
                    ),
                  ),
                _sectionTitle(context, 'Marka'),
                TextField(
                  controller: _appName,
                  enabled: can && !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Uygulama adı',
                    hintText: 'Ustasından',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _tagline,
                  enabled: can && !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Kısa slogan',
                    hintText: 'Bölgendeki ustalar, tek uygulamada',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _logoUrl,
                  enabled: can && !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Logo URL (https)',
                    hintText: 'Yükle veya URL yapıştır',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: (!can || _busy) ? null : _uploadLogo,
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: const Text('Galeriden logo yükle'),
                    ),
                    const SizedBox(width: 12),
                    if (_logoUrl.text.trim().isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: AppImage(
                            handle: _logoUrl.text.trim(),
                            width: 48,
                            height: 48,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _about,
                  enabled: can && !_busy,
                  maxLines: 4,
                  maxLength: 800,
                  decoration: const InputDecoration(
                    labelText: 'Hakkında (kısa)',
                    alignLabelWithHint: true,
                  ),
                ),
                _sectionTitle(context, 'Destek & mağaza'),
                TextField(
                  controller: _supportEmail,
                  enabled: can && !_busy,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Destek e-posta',
                    prefixIcon: Icon(Icons.mail_outline, size: 20),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _supportPhone,
                  enabled: can && !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Destek telefon (opsiyonel)',
                    prefixIcon: Icon(Icons.phone_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _play,
                  enabled: can && !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Play Store URL',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _appStore,
                  enabled: can && !_busy,
                  decoration: const InputDecoration(
                    labelText: 'App Store URL',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _web,
                  enabled: can && !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Web / landing URL',
                  ),
                ),
                _sectionTitle(context, 'Uygulama içi duyuru'),
                Text(
                  'Keşfet üstünde bant olarak görünür (tüketici uygulaması).',
                  style: TextStyle(color: palette.inkMuted, fontSize: 13),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Duyuru aktif'),
                  value: _annEnabled,
                  onChanged: (!can || _busy)
                      ? null
                      : (v) => setState(() => _annEnabled = v),
                ),
                TextField(
                  controller: _annTitle,
                  enabled: can && !_busy,
                  decoration: const InputDecoration(labelText: 'Başlık'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _annBody,
                  enabled: can && !_busy,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Metin',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _annCta,
                  enabled: can && !_busy,
                  decoration: const InputDecoration(
                    labelText: 'CTA etiketi (opsiyonel)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _annCtaUrl,
                  enabled: can && !_busy,
                  decoration: const InputDecoration(
                    labelText: 'CTA link (https, opsiyonel)',
                  ),
                ),
                if (cfg.updatedAt != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Son güncelleme: ${cfg.updatedAt!.toLocal()}'
                    '${cfg.updatedBy != null ? ' · ${cfg.updatedBy}' : ''}',
                    style: TextStyle(color: palette.inkFaint, fontSize: 12),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String t) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        t,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}
