import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/searchable_select_field.dart';
import '../../../data/local/local_data_service.dart';
import '../../../data/models/geo_models.dart';
import '../../artisan/application/my_profile_controller.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/provider_phone_gate.dart';
import '../data/product_category_providers.dart';

/// Mağaza (satıcı) profili ilk kurulum VE sonradan düzenleme.
///
/// Kategori + hizmet bölgesi. Bölge müşteriye görünür (dükkân kartı).
/// Usta profilinde hizmet bölgesi varsa ilk açılışta kopyalanır.
class ShopSetupScreen extends ConsumerStatefulWidget {
  const ShopSetupScreen({super.key, this.editing = false});

  /// true: mevcut kategori/bölge doldurulur, "Kaydet".
  final bool editing;

  @override
  ConsumerState<ShopSetupScreen> createState() => _ShopSetupScreenState();
}

class _ShopSetupScreenState extends ConsumerState<ShopSetupScreen> {
  final Set<String> _selected = {};
  final List<ServiceArea> _areas = [];
  Province? _addProvince;
  District? _addDistrict;
  bool _busy = false;
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
  }

  bool get _isEdit {
    if (widget.editing) return true;
    return ref.read(currentUserProvider)?.hasShopProfile ?? false;
  }

  void _prefill() {
    if (_prefilled) return;
    final user = ref.read(currentUserProvider);
    if (user != null &&
        (widget.editing || user.hasShopProfile) &&
        (user.shopCategories.isNotEmpty || user.shopServiceAreas.isNotEmpty)) {
      setState(() {
        _selected
          ..clear()
          ..addAll(user.shopCategories);
        _areas
          ..clear()
          ..addAll(user.shopServiceAreas);
        _prefilled = true;
      });
      return;
    }
    final draft = ref.read(myProfileControllerProvider).valueOrNull;
    final areas = draft?.profile.serviceAreas ?? const <ServiceArea>[];
    if (areas.isEmpty) return;
    setState(() {
      _areas
        ..clear()
        ..addAll(areas);
      _prefilled = true;
    });
  }

  void _addArea() {
    final p = _addProvince;
    final d = _addDistrict;
    if (p == null || d == null) {
      context.showInfo('Lütfen il ve ilçe seçin.');
      return;
    }
    final area = ServiceArea(province: p.name, district: d.name);
    if (_areas.any((a) => a.key == area.key)) {
      context.showInfo('Bu bölge zaten ekli.');
      return;
    }
    setState(() {
      _areas.add(area);
      _addDistrict = null;
    });
  }

  Future<void> _submit() async {
    if (_selected.isEmpty) {
      context.showError('En az bir satış kategorisi seçin.');
      return;
    }
    // Bekleyen il+ilçe seçimi kaydetmeden ekle (usta profili ile aynı UX).
    if (_addProvince != null && _addDistrict != null) {
      final pending = ServiceArea(
        province: _addProvince!.name,
        district: _addDistrict!.name,
      );
      if (!_areas.any((a) => a.key == pending.key)) {
        _areas.add(pending);
      }
    }
    if (_areas.isEmpty) {
      context.showError('En az bir hizmet bölgesi ekleyin.');
      return;
    }
    // TELEFON DOĞRULAMASI ZORUNLU (new.md madde 1–2). Usta kaydıyla aynı
    // kapı: doğrulanmazsa mağaza AÇILMAZ, seçimler ekranda kalır.
    //
    // `_busy` kapıdan ÖNCE açılır: aksi hâlde doğrulama sayfası açıkken
    // "Mağazayı aç" düğmesi etkin kalır ve ikinci basış ikinci bir sayfa
    // açardı (çift gönderim).
    setState(() => _busy = true);
    final bool telefonOk;
    try {
      telefonOk = await ensureVerifiedPhoneForProvider(
        context,
        ref,
        isShop: true,
      );
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      rethrow;
    }
    if (!telefonOk) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (!mounted) return;
    try {
      final edit = _isEdit;
      await ref.read(authRepositoryProvider).updateUserProfile(
            hasShopProfile: true,
            shopCategories: _selected.toList(),
            shopServiceAreas: List.of(_areas),
            available: edit ? null : true,
          );
      if (!mounted) return;
      context.showSuccess(
        edit
            ? 'Mağaza bilgileri güncellendi.'
            : 'Mağazanız açıldı. Ürün ekleyebilirsiniz.',
      );
      // KAYIT SONRASI PROFİLE DÖN (2026-08-14 kullanıcı bulgusu).
      //
      // `context.pop()` yığına bağlıydı: derin bağlantıyla ya da yönlendirme
      // sonrası açıldığında geri gidilecek sayfa olmayabiliyor ve kullanıcı
      // "Kaydet"e bastıktan sonra AYNI formda kalıyordu — kaydın çalışıp
      // çalışmadığı belirsiz görünüyordu.
      //
      // `go` yığını sıfırlar ve her durumda profile düşer (usta profili
      // düzenleme ekranıyla aynı desen).
      context.go(RoutePaths.profile);
    } catch (_) {
      if (mounted) {
        context.showError('Mağaza açılamadı. Tekrar deneyin.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Usta profili sonradan yüklenebilir — alan boşsa bir kez daha dene.
    ref.listen(myProfileControllerProvider, (prev, next) {
      if (!_prefilled &&
          (next.valueOrNull?.profile.serviceAreas.isNotEmpty ?? false)) {
        _prefill();
      }
    });
    final edit = _isEdit;

    final palette = context.palette;
    final theme = Theme.of(context);
    final provincesAsync = ref.watch(provincesProvider);
    final catalog = catalogOf(ref);

    return Scaffold(
      appBar: GradientAppBar(
        title: edit ? 'Mağazayı düzenle' : 'Satış yapmaya başla',
        icon: Icons.storefront_outlined,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? '…' : (edit ? 'Kaydet' : 'Mağazayı aç')),
          ),
        ),
      ),
      body: ResponsiveCenter(
        maxWidth: 560,
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              '1 · Ne satacaksınız?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Bir veya daha fazla kategori seçin. Sonra ürün fotoğrafı '
              'ekleyip vitrininizi doldurabilirsiniz.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.inkMuted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            // Kategoriler ETİKET (chip) değil LİSTE olarak gösterilir:
            // ~28 kategori chip hâlinde sayfayı şişiriyor, altındaki bölge
            // adımı ekrandan düşüyordu. Kendi içinde kayan sabit yükseklikli
            // kutu, listeyi tarayıp seçmeyi kolaylaştırır.
            //
            // Dıştaki ListView sınırsız yükseklik verdiği için kutunun
            // yüksekliği AÇIKÇA verilmeli, yoksa kaydırma çakışır.
            Container(
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: palette.border),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: catalog.sirali.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  thickness: 1,
                  color: palette.border,
                ),
                itemBuilder: (_, i) {
                  final code = catalog.sirali[i];
                  return CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(catalog.label(code)),
                    value: _selected.contains(code),
                    onChanged: (v) {
                      setState(() {
                        if (v ?? false) {
                          _selected.add(code);
                        } else {
                          _selected.remove(code);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selected.isEmpty
                  ? 'Henüz kategori seçilmedi'
                  : '${_selected.length} kategori seçildi',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.inkMuted,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              '2 · Hizmet bölgesi',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Hangi il/ilçelerde satış yapıyorsunuz? Müşteriler '
              'mağazanızın yerini burada görür. Usta profilinizde bölge '
              'seçtiyseniz ilk açılışta otomatik aktarılır.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.inkMuted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            provincesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const Text('İl verisi yüklenemedi'),
              data: (provinces) => SearchableSelectField<Province>(
                label: 'İl',
                value: _addProvince,
                items: provinces,
                itemLabel: (p) => p.name,
                searchHint: 'İl ara…',
                prefixIcon: Icons.map_outlined,
                equals: (a, b) => a.id == b.id,
                onSelected: (p) => setState(() {
                  _addProvince = p;
                  _addDistrict = null;
                }),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _addProvince == null
                      ? SearchableSelectField<District>(
                          label: 'İlçe',
                          value: null,
                          items: const [],
                          itemLabel: (d) => d.name,
                          enabled: false,
                          hint: 'Önce il seçin',
                          onSelected: (_) {},
                        )
                      : ref.watch(districtsProvider(_addProvince!.id)).when(
                            loading: () => const LinearProgressIndicator(),
                            error: (_, _) =>
                                const Text('İlçe verisi yüklenemedi'),
                            data: (districts) =>
                                SearchableSelectField<District>(
                              label: 'İlçe',
                              value: _addDistrict,
                              items: districts,
                              itemLabel: (d) => d.name,
                              searchHint: 'İlçe ara…',
                              prefixIcon: Icons.location_city_outlined,
                              equals: (a, b) => a.id == b.id,
                              onSelected: (d) =>
                                  setState(() => _addDistrict = d),
                            ),
                          ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: _addArea,
                  style:
                      FilledButton.styleFrom(minimumSize: const Size(64, 56)),
                  child: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_areas.isEmpty)
              Text(
                _addProvince != null && _addDistrict != null
                    ? 'Seçtiğiniz bölge kaydederken eklenecek. '
                        'Birden fazla bölge için “+” kullanın.'
                    : 'Henüz bölge eklemediniz.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.inkMuted,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in _areas)
                    Chip(
                      label: Text(a.labelTR),
                      onDeleted: () => setState(() => _areas.remove(a)),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
