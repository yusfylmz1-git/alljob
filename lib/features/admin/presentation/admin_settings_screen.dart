import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/status_views.dart';
import '../../legal/legal_docs.dart';
import '../data/admin_providers.dart';
import '../data/admin_runtime_config_repository.dart';
import 'admin_chrome.dart';

/// Sistem bayrakları: beta premium, bakım, min sürüm + yasal linkler.
class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() =>
      _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  bool _busy = false;
  final _minVersion = TextEditingController();
  bool _minSeeded = false;

  @override
  void dispose() {
    _minVersion.dispose();
    super.dispose();
  }

  Future<void> _saveMin(AdminRuntimeConfig current) async {
    final can = ref.read(adminCapabilitiesProvider).allows('config.manage');
    if (!can) {
      context.showError('config.manage yetkisi yok.');
      return;
    }
    setState(() => _busy = true);
    try {
      final raw = _minVersion.text.trim();
      await ref.read(adminRuntimeConfigRepositoryProvider).update({
        if (raw.isEmpty) 'minAppVersion': null else 'minAppVersion': raw,
      });
      if (!mounted) return;
      context.showSuccess('Min. sürüm kaydedildi.');
    } catch (_) {
      if (!mounted) return;
      context.showError('Kaydedilemedi (CF / yetki).');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _patch(Map<String, dynamic> patch) async {
    final can = ref.read(adminCapabilitiesProvider).allows('config.manage');
    if (!can) {
      context.showError('config.manage yetkisi yok.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(adminRuntimeConfigRepositoryProvider).update(patch);
      if (!mounted) return;
      context.showSuccess('Güncellendi.');
    } catch (_) {
      if (!mounted) return;
      context.showError('Güncellenemedi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final cfgAsync = ref.watch(adminRuntimeConfigProvider);
    final canManage =
        ref.watch(adminCapabilitiesProvider).allows('config.manage');

    return Scaffold(
      backgroundColor: AdminChrome.surface,
      appBar: AdminChrome.pageHeader(
        context: context,
        title: 'Sistem ayarları',
        icon: Icons.tune_outlined,
        subtitle: 'Bakım · beta · zorunlu sürüm',
      ),
      body: cfgAsync.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(
          message: 'Config okunamadı (rules / ağ).',
        ),
        data: (cfg) {
          if (!_minSeeded) {
            _minSeeded = true;
            final v = cfg.minAppVersion;
            if (v != null && v.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _minVersion.text = v;
              });
            }
          }
          return ResponsiveCenter(
            maxWidth: 720,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: ListView(
              children: [
                Text(
                  'Operasyon bayrakları',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tüketici uygulaması bu alanları canlı okur '
                  '(adminConfig/runtime).',
                  style: TextStyle(color: palette.inkMuted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Premium beta ücretsiz'),
                  subtitle: const Text(
                      'Usta Pro özellikleri Beta planında açık'),
                  value: cfg.premiumFreeDuringBeta,
                  onChanged: (!canManage || _busy)
                      ? null
                      : (v) => _patch({'premiumFreeDuringBeta': v}),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bakım modu'),
                  subtitle: const Text(
                      'Açıkken kullanıcılar bakım ekranına yönlenir'),
                  value: cfg.maintenanceMode,
                  onChanged: (!canManage || _busy)
                      ? null
                      : (v) => _patch({'maintenanceMode': v}),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _minVersion,
                  enabled: canManage && !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Min. uygulama sürümü',
                    hintText: 'ör. 1.2.0 — boş = zorunlu güncelleme yok',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed:
                      (!canManage || _busy) ? null : () => _saveMin(cfg),
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Min. sürümü kaydet'),
                ),
                if (cfg.updatedAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Son güncelleme: ${cfg.updatedAt!.toLocal()} '
                    '${cfg.updatedBy != null ? "· ${cfg.updatedBy}" : ""}',
                    style: TextStyle(color: palette.inkFaint, fontSize: 12),
                  ),
                ],
                const Divider(height: 36),
                Text(
                  'Yasal URL’ler (kod + hosting)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.mail_outline),
                  title: const Text('Varsayılan iletişim (kod)'),
                  subtitle: Text(kLegalContactEmail),
                  trailing: IconButton(
                    tooltip: 'Kopyala',
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () async {
                      await Clipboard.setData(
                          ClipboardData(text: kLegalContactEmail));
                      if (context.mounted) {
                        context.showSuccess('Kopyalandı.');
                      }
                    },
                  ),
                ),
                Text(
                  'Canlı destek e-postasını Platform & marka ekranından '
                  'yönetin (runtime). Yasal metinler kod + HTML hosting.',
                  style: TextStyle(color: palette.inkMuted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  '$kLegalBaseUrl/gizlilik-politikasi.html\n'
                  '$kLegalBaseUrl/kullanim-kosullari.html\n'
                  '$kLegalBaseUrl/kvkk-aydinlatma.html\n'
                  '$kLegalBaseUrl/hesap-silme.html',
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.inkMuted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
