import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/searchable_select_field.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/local/local_data_service.dart';
import '../../../data/models/geo_models.dart';
import '../../legal/legal_docs.dart';
import '../data/admin_providers.dart';
import '../data/admin_runtime_config_repository.dart';
import 'admin_chrome.dart';
import 'admin_product_categories_section.dart';

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
    final canManage = ref
        .watch(adminCapabilitiesProvider)
        .allows('config.manage');

    return Scaffold(
      backgroundColor: AdminChrome.surface,
      appBar: AdminChrome.pageHeader(
        context: context,
        title: 'Sistem ayarları',
        icon: Icons.tune_outlined,
        subtitle: 'Bakım · beta · Mağaza · zorunlu sürüm',
      ),
      body: cfgAsync.when(
        loading: () => const LoadingView(),
        error: (_, _) =>
            const ErrorView(message: 'Config okunamadı (rules / ağ).'),
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
                    'Usta Pro özellikleri Beta planında açık',
                  ),
                  value: cfg.premiumFreeDuringBeta,
                  onChanged: (!canManage || _busy)
                      ? null
                      : (v) => _patch({'premiumFreeDuringBeta': v}),
                ),
                // ÜCRETLİ İLLER (2026-08-23) — şehir bazlı Pro geçişi.
                //
                // Bu liste bir KAPI'dır, veri yazmaz: il eklendiği an o ilde
                // aboneliği olmayan kullanıcının müsaitliği düşer, il
                // çıkarılınca herkes eski hâline kendiliğinden döner.
                //
                // Toplu plan ekranındaki yıkıcı işlemlerle karıştırılmamalı:
                // orası veri yazar ve geri alınamaz.
                if (cfg.premiumFreeDuringBeta) ...[
                  const SizedBox(height: 8),
                  _UcretliIller(
                    iller: cfg.paidProvinces,
                    enabled: canManage && !_busy,
                    onChanged: (yeni) => _patch({'paidProvinces': yeni}),
                  ),
                ],
                const SizedBox(height: 8),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bakım modu'),
                  subtitle: const Text(
                    'Açıkken kullanıcılar bakım ekranına yönlenir',
                  ),
                  value: cfg.maintenanceMode,
                  onChanged: (!canManage || _busy)
                      ? null
                      : (v) => _patch({'maintenanceMode': v}),
                ),
                const Divider(height: 28),
                Text(
                  'Mağaza',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ürün vitrini kill-switch ve yayın denetimi. '
                  'Deploy gerekmez; uygulama canlı okur.',
                  style: TextStyle(color: palette.inkMuted, fontSize: 13),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mağaza ürün vitrini açık'),
                  subtitle: const Text(
                    'Kapalıyken Keşfet’te ürün listesi ve Dükkân gizlenir; '
                    'yeni yayın reddedilir. Talepler (ürün talebi ilanı) etkilenmez.',
                  ),
                  value: cfg.productsEnabled,
                  onChanged: (!canManage || _busy)
                      ? null
                      : (v) => _patch({'productsEnabled': v}),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ürün yayınında zorunlu inceleme'),
                  subtitle: const Text(
                    'Açıkken her yayın “İncelemede” kalır; admin onaylamadan '
                    'vitrine düşmez. İletişim kalıbı zaten otomatik inceleme tetikler.',
                  ),
                  value: cfg.productsForceReview,
                  onChanged: (!canManage || _busy)
                      ? null
                      : (v) => _patch({'productsForceReview': v}),
                ),
                const Divider(height: 28),
                const AdminProductCategoriesSection(),
                const SizedBox(height: 16),
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
                  onPressed: (!canManage || _busy) ? null : () => _saveMin(cfg),
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
                        ClipboardData(text: kLegalContactEmail),
                      );
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

/// ÜCRETLİ döneme geçmiş illerin listesi (2026-08-23).
///
/// Şehir bazlı Pro geçişinin tek kontrol noktası. Ekleme/çıkarma anında
/// etkilidir ve **hiçbir veri yazmaz** — kapı yalnız okur. Yanlış giderse
/// il çıkarılır, herkes eski hâline döner.
class _UcretliIller extends ConsumerWidget {
  const _UcretliIller({
    required this.iller,
    required this.enabled,
    required this.onChanged,
  });

  final List<String> iller;
  final bool enabled;
  final void Function(List<String>) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Ücretli iller', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          iller.isEmpty
              ? 'Liste boş — tüm iller betada, kimse ödemiyor.'
              : '${iller.length} il ücretli dönemde. Bu illerde aboneliği '
                  'olmayan kullanıcının müsaitliği kapalıdır.',
          style: TextStyle(color: palette.inkMuted, fontSize: 12.5),
        ),
        const SizedBox(height: 8),
        if (iller.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final il in iller)
                Chip(
                  label: Text(il),
                  onDeleted: enabled
                      ? () => onChanged(
                            iller.where((e) => e != il).toList(growable: false),
                          )
                      : null,
                ),
            ],
          ),
        const SizedBox(height: 8),
        ref.watch(provincesProvider).when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const Text('İl verisi yüklenemedi'),
              data: (hepsi) {
                final kalan = hepsi
                    .where((p) => !iller.contains(p.name))
                    .toList(growable: false);
                return SearchableSelectField<Province>(
                  label: 'İl ekle',
                  value: null,
                  items: kalan,
                  itemLabel: (p) => p.name,
                  searchHint: 'İl ara…',
                  prefixIcon: Icons.add_location_alt_outlined,
                  enabled: enabled,
                  equals: (a, b) => a.id == b.id,
                  onSelected: (p) async {
                    // Geçiş bir ilan kadar görünür bir karar: sessizce
                    // eklenmemeli.
                    final onay = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('${p.name} ücretli döneme geçsin mi?'),
                        content: Text(
                          '${p.name} ilinde aboneliği olmayan kullanıcıların '
                          'müsaitliği KAPANIR; aramada görünmez ve iş '
                          'alamazlar.\n\n'
                          'Hiçbir veri değişmez — ili listeden çıkarırsanız '
                          'herkes eski hâline döner.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Vazgeç'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Ücretliye geçir'),
                          ),
                        ],
                      ),
                    );
                    if (onay != true) return;
                    onChanged([...iller, p.name]);
                  },
                );
              },
            ),
      ],
    );
  }
}
