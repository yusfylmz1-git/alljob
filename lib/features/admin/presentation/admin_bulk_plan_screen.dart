import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_runtime_config.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/searchable_select_field.dart';
import '../../../data/local/local_data_service.dart';
import '../../../data/models/geo_models.dart';
import '../data/admin_artisan_repository.dart';
import '../data/admin_providers.dart';

/// Toplu plan yönetimi — ücretsiz dönem bitişi (Yapılacaklar madde 7).
///
/// ÖNCE ŞUNU BİL: müsaitliğin ücretsiz dönem bitince kapanmasını sağlayan
/// asıl mekanizma BU EKRAN DEĞİL, istemcideki premium kapısıdır
/// (`ArtisanProfile.isAvailableAt` premium erişimi yoksa false döner).
/// O kapı hiçbir veri yazmaz; "Premium beta ücretsiz" anahtarı kapandığı an
/// premium olmayan ustalar aramada görünmez olur ve anahtar geri açılırsa
/// herkes eski hâline kendiliğinden döner.
///
/// Bu ekran o kapının YANINDA durur: yöneticinin veriyi gerçekten değiştirmesi
/// gereken durumlar için (kampanya bitişi, toplu düzeltme, kötüye kullanım).
/// Yazdığı şey kalıcıdır ve "geri al" düğmesi YOKTUR — bu yüzden her işlem
/// önce kuru çalışma (önizleme) ile kaç ustayı etkileyeceğini gösterir.
class AdminBulkPlanScreen extends ConsumerStatefulWidget {
  const AdminBulkPlanScreen({super.key});

  @override
  ConsumerState<AdminBulkPlanScreen> createState() =>
      _AdminBulkPlanScreenState();
}

class _AdminBulkPlanScreenState extends ConsumerState<AdminBulkPlanScreen> {
  /// `revokePremium` · `pauseAvailability` · `both`
  String _mode = 'pauseAvailability';
  final _reason = TextEditingController();

  /// Hedef il — ZORUNLU (2026-08-23).
  ///
  /// Önce yoktu ve işlem TÜM koleksiyonu tarıyordu: Bursa'yı geçirmek
  /// isteyen yönetici Türkiye'deki her ustanın müsaitliğini kapatabiliyordu
  /// ve işlem geri alınamıyor. Şehir bazlı geçişe geçilince bu artık teorik
  /// bir risk değil, günlük bir işlem.
  ///
  /// "Tümü" seçeneği BİLEREK YOK: birinin yanlışlıkla seçmesi an meselesi.
  /// Ülke geneli işlem gerekirse iller tek tek seçilir.
  Province? _il;

  /// Parasını ödemiş aktif aboneler atlansın mı? (varsayılan: evet)
  bool _skipPaying = true;

  bool _busy = false;

  /// Son kuru çalışma sonucu — onay düğmesi ancak bu doluyken açılır.
  BulkPlanResult? _preview;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _reasonOk => _reason.text.trim().length >= 5;

  /// Kuru çalışma: hiçbir şey yazılmaz, yalnız sayım döner.
  Future<void> _onizle() async {
    if (!_guard()) return;
    setState(() => _busy = true);
    try {
      final res = await ref.read(adminArtisanRepositoryProvider).bulkPlanUpdate(
            province: _il!.name,
            mode: _mode,
            reason: _reason.text.trim(),
            onlyWithoutActivePremium: _skipPaying,
            dryRun: true,
          );
      if (!mounted) return;
      setState(() => _preview = res);
    } catch (e) {
      if (!mounted) return;
      context.showError('Önizleme alınamadı: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Gerçek yazma — önizleme sonrası ikinci bir onay diyaloğu ister.
  Future<void> _uygula() async {
    if (!_guard()) return;
    final p = _preview;
    if (p == null) return;

    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Toplu işlemi uygula'),
        content: Text(
          '${_il?.name} ilinde ${p.etkilenen} usta etkilenecek '
          '(ildeki toplam ${p.toplam}). Bu işlem GERİ ALINAMAZ.\n\n'
          '${_modeAciklama(_mode)}\n\n'
          'Gerekçe denetim kaydına yazılacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.palette.danger,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Uygula'),
          ),
        ],
      ),
    );
    if (onay != true) return;

    setState(() => _busy = true);
    try {
      final res = await ref.read(adminArtisanRepositoryProvider).bulkPlanUpdate(
            province: _il!.name,
            mode: _mode,
            reason: _reason.text.trim(),
            onlyWithoutActivePremium: _skipPaying,
          );
      if (!mounted) return;
      setState(() => _preview = null);
      context.showSuccess(
        '${_il?.name}: ${res.etkilenen} usta güncellendi '
        '(${res.atlanan} atlandı).',
      );
    } catch (e) {
      if (!mounted) return;
      context.showError('İşlem başarısız: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Yetki + gerekçe kapısı. UI zaten kilitler; bu ikinci savunma hattı.
  bool _guard() {
    if (!ref.read(adminCapabilitiesProvider).allows('finance.manage')) {
      context.showError('finance.manage yetkisi yok.');
      return false;
    }
    if (_il == null) {
      context.showError('Hedef il seçin.');
      return false;
    }
    if (!_reasonOk) {
      context.showError('Gerekçe zorunlu (en az 5 karakter).');
      return false;
    }
    return true;
  }

  static String _modeAciklama(String mode) => switch (mode) {
        'revokePremium' =>
          'Premium bayrağı kapatılacak (müsaitlik ayarına dokunulmaz).',
        'pauseAvailability' =>
          'Müsaitlik duraklatılacak (usta kendisi tekrar açabilir).',
        _ => 'Hem premium kapatılacak hem müsaitlik duraklatılacak.',
      };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final canManage =
        ref.watch(adminCapabilitiesProvider).allows('finance.manage');
    final freeBeta = ref.watch(appRuntimeConfigProvider).valueOrNull
        ?.premiumFreeDuringBeta;

    return ResponsiveCenter(
      maxWidth: 720,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: ListView(
        children: [
          Text(
            'Toplu plan yönetimi',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Ücretsiz dönem bitişinde ustaların planını / müsaitliğini toplu '
            'değiştirir. Yazdığı veri kalıcıdır.',
            style: TextStyle(color: palette.inkMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // Asıl mekanizmayı hatırlatan bant: yönetici bu ekranı gereksiz
          // yere kullanmasın. Ücretsiz dönem HÂLÂ açıkken toplu kapatma
          // yapmak neredeyse her zaman yanlıştır.
          if (freeBeta == true)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: palette.warning.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 20, color: palette.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '"Premium beta ücretsiz" anahtarı HÂLÂ AÇIK. Ücretsiz '
                      'döneme son vermek istiyorsan önce Sistem ekranından o '
                      'anahtarı kapat — premium olmayan ustaların müsaitliği '
                      'kendiliğinden kapanır ve hiçbir veri değişmez. Buradaki '
                      'toplu işlem geri alınamaz.',
                      style: TextStyle(fontSize: 13, color: palette.ink),
                    ),
                  ),
                ],
              ),
            ),

          // HEDEF İL — zorunlu. Seçilmeden önizleme/uygula açılmaz.
          Text('Hedef il', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          ref.watch(provincesProvider).when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text('İl verisi yüklenemedi'),
                data: (iller) => SearchableSelectField<Province>(
                  label: 'İl',
                  value: _il,
                  items: iller,
                  itemLabel: (p) => p.name,
                  searchHint: 'İl ara…',
                  prefixIcon: Icons.map_outlined,
                  enabled: canManage && !_busy,
                  equals: (a, b) => a.id == b.id,
                  onSelected: (p) => setState(() {
                    _il = p;
                    _preview = null; // il değişti → önizleme geçersiz
                  }),
                ),
              ),
          const SizedBox(height: 6),
          Text(
            'İşlem yalnız seçilen ildeki ustaları etkiler. "Tümü" seçeneği '
            'YOKTUR — ülke geneli bir işlem gerekiyorsa illeri tek tek '
            'seçin.',
            style: TextStyle(color: palette.inkMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 16),

          Text('İşlem', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          RadioGroup<String>(
            groupValue: _mode,
            onChanged: (v) {
              if (!canManage || _busy) return; // yetkisizken seçim yutulur
              setState(() {
                _mode = v ?? _mode;
                _preview = null; // mod değişti → önizleme geçersiz
              });
            },
            child: const Column(
              children: [
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: 'pauseAvailability',
                  title: Text('Müsaitliği duraklat'),
                  subtitle: Text('manualPause = true; usta kendisi açabilir'),
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: 'revokePremium',
                  title: Text('Premium\'u kapat'),
                  subtitle: Text('isPremium = false; müsaitliğe dokunmaz'),
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: 'both',
                  title: Text('İkisi birden'),
                  subtitle: Text('Premium kapat + müsaitliği duraklat'),
                ),
              ],
            ),
          ),
          const Divider(height: 24),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ödeme yapan aboneleri atla'),
            subtitle: const Text(
              'Aktif ve süresi dolmamış aboneliği olan ustalara dokunulmaz',
            ),
            value: _skipPaying,
            onChanged: (!canManage || _busy)
                ? null
                : (v) => setState(() {
                      _skipPaying = v;
                      _preview = null;
                    }),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _reason,
            enabled: canManage && !_busy,
            maxLength: 500,
            maxLines: 2,
            onChanged: (_) => setState(() => _preview = null),
            decoration: const InputDecoration(
              labelText: 'Gerekçe (zorunlu)',
              hintText: 'ör. Beta dönemi 2026-09-01 itibarıyla sona erdi',
              helperText: 'Denetim kaydına yazılır — en az 5 karakter',
            ),
          ),
          const SizedBox(height: 8),

          if (!canManage)
            Text(
              'Bu işlem finance.manage yetkisi ister.',
              style: TextStyle(color: palette.danger, fontSize: 13),
            ),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  // İl seçilmeden önizleme de alınamaz: sunucu zaten
                  // reddederdi, ama düğmeyi kilitlemek hatayı hiç
                  // doğurmamak demek.
                  onPressed: (!canManage || _busy || !_reasonOk || _il == null)
                      ? null
                      : _onizle,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Önizle'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.danger,
                  ),
                  // Önizleme YAPILMADAN uygulanamaz: geri alınamaz bir işlem
                  // için yöneticinin kaç ustayı etkilediğini görmesi şart.
                  onPressed: (!canManage || _busy || _preview == null)
                      ? null
                      : _uygula,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Uygula'),
                ),
              ),
            ],
          ),

          if (_busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],

          if (_preview != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Önizleme (hiçbir şey yazılmadı)',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  _satir('Etkilenecek usta', '${_preview!.etkilenen}'),
                  _satir('Atlanacak', '${_preview!.atlanan}'),
                  _satir('Toplam usta', '${_preview!.toplam}'),
                  const SizedBox(height: 8),
                  Text(
                    _modeAciklama(_mode),
                    style: TextStyle(color: palette.inkMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _satir(String etiket, String deger) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(etiket),
            Text(deger, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );
}
