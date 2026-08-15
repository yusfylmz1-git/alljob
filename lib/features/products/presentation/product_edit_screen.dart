import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/photo_picker.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/disclaimer_note.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/role_bottom_bar.dart';
import '../../../core/widgets/searchable_select_field.dart';
import '../../../core/widgets/status_views.dart';
import '../../../data/local/local_data_service.dart';
import '../../../data/models/geo_models.dart';
import '../../../data/models/product.dart';
import '../../../data/models/product_category.dart';
import '../../artisan/application/my_profile_controller.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/email_verification_gate.dart';
import '../../storage/storage_repository.dart';
import '../data/product_category_providers.dart';
import '../data/product_providers.dart';
import '../../../core/utils/app_log.dart';

/// Yeni ürün veya mevcut ürün düzenleme.
class ProductEditScreen extends ConsumerStatefulWidget {
  const ProductEditScreen({super.key, this.productId});

  final String? productId;

  @override
  ConsumerState<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends ConsumerState<ProductEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _tags = TextEditingController();

  Province? _province;
  District? _district;

  Product? _loaded;
  String? _productId;
  bool _loading = true;
  bool _loadFailed = false;
  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _categoryCode;
  ProductPriceType _priceType = ProductPriceType.negotiable;
  ProductCondition _condition = ProductCondition.handmade;
  final List<String> _photos = [];
  ProductStatus _status = ProductStatus.draft;

  bool get _isNew => widget.productId == null && _productId == null;
  bool get _contentLocked =>
      _status != ProductStatus.draft && _status != ProductStatus.removed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      if (widget.productId == null) {
        final draft = ref.read(myProfileControllerProvider).valueOrNull;
        final user = ref.read(currentUserProvider);
        // Önce usta hizmet bölgeleri; yoksa mağaza bölgeleri.
        final areas = (draft?.profile.serviceAreas.isNotEmpty ?? false)
            ? draft!.profile.serviceAreas
            : (user?.shopServiceAreas ?? const <ServiceArea>[]);
        final loc = areas.isEmpty
            ? (province: null as Province?, district: null as District?)
            : await _resolveLocation(
                areas.first.province, areas.first.district);
        if (!mounted) return;
        setState(() {
          _province = loc.province;
          _district = loc.district;
          // Kategori ön-seçimi KALDIRILDI (2026-08-10): kullanıcının
          // MESLEĞİ ürün kategorisi olarak dolduruluyordu. Artık ikisi ayrı
          // listeler — meslek kodu ürün kategorisi değil. Ayrıca "herkes
          // satabilir" olduğu için satıcının mesleği hiç olmayabilir.
          _loading = false;
        });
        return;
      }
      final p = await ref
          .read(productRepositoryProvider)
          .getProduct(widget.productId!);
      if (!mounted) return;
      if (p == null) {
        setState(() => _loading = false);
        return;
      }
      final loc = await _resolveLocation(p.province, p.district);
      if (!mounted) return;
      _applyProduct(p);
      setState(() {
        _province = loc.province;
        _district = loc.district;
        _loading = false;
      });
    } catch (_) {
      // Ağ/önbellek hatası: sonsuz yükleme yerine hata + tekrar dene.
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  /// Kayıtlı il/ilçe adlarını statik listelerdeki kayıtlara çözümler.
  /// Eşleşme yoksa null döner (kullanıcı listeden yeniden seçer).
  Future<({Province? province, District? district})> _resolveLocation(
    String? provinceName,
    String? districtName,
  ) async {
    final name = provinceName?.trim() ?? '';
    if (name.isEmpty) return (province: null, district: null);
    final data = ref.read(localDataServiceProvider);
    final provinces = await data.getProvinces();
    Province? p;
    for (final x in provinces) {
      if (x.name == name) {
        p = x;
        break;
      }
    }
    if (p == null) return (province: null, district: null);
    final dName = districtName?.trim() ?? '';
    if (dName.isEmpty) return (province: p, district: null);
    final districts = await data.getDistricts(p.id);
    District? d;
    for (final x in districts) {
      if (x.name == dName) {
        d = x;
        break;
      }
    }
    return (province: p, district: d);
  }

  void _applyProduct(Product p) {
    _loaded = p;
    _productId = p.id;
    _title.text = p.title;
    _desc.text = p.description;
    _categoryCode = p.categoryCode;
    _priceType = p.priceType;
    _condition = p.condition;
    _photos
      ..clear()
      ..addAll(p.photos);
    _status = p.status;
    if (p.priceAmount != null) {
      _price.text = p.priceAmount!.round().toString();
    } else {
      _price.clear();
    }
    _tags.text = p.tags.join(', ');
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _price.dispose();
    _tags.dispose();
    super.dispose();
  }

  List<String> _parseTags() {
    return _tags.text
        .split(RegExp(r'[,;]'))
        .map((s) => s.trim())
        .where((s) => s.length >= 2 && s.length <= 24)
        .take(AppConstants.maxProductTags)
        .toList();
  }

  double? _parsePrice() {
    if (_priceType == ProductPriceType.negotiable) return null;
    return Validators.parseTrAmount(_price.text);
  }

  /// Kamera veya galeri seçimi (usta profil / iş ilanı paritesi).
  Future<ImageSource?> _chooseImageSource() {
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
                subtitle: const Text('Yeni fotoğraf çekin'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library_outlined,
                    color: palette.primary),
                title: const Text('Galeriden seç'),
                subtitle: const Text('Mevcut fotoğraflardan'),
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
    if (_uploadingPhoto) return;
    if (_photos.length >= AppConstants.maxProductPhotos) {
      context.showError(
          'En fazla ${AppConstants.maxProductPhotos} fotoğraf ekleyebilirsiniz.');
      return;
    }
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.push(RoutePaths.login);
      return;
    }
    final source = await _chooseImageSource();
    if (source == null || !mounted) return;

    // Her fotoğraf yüklemeden ÖNCE 4:5 kırpılır — vitrin ızgarası aynı
    // oranda; kırpma olmadan dikey fotoğrafın altı/üstü kesiliyordu.
    final List<Uint8List> files;
    try {
      files = await PhotoPicker.pickMultiPhoto(
        context,
        source: source,
        limit: AppConstants.maxProductPhotos - _photos.length,
        title: 'Ürün fotoğrafı',
      );
    } catch (_) {
      if (mounted) {
        context.showError(source == ImageSource.camera
            ? 'Kamera açılamadı. İzinleri kontrol edin.'
            : 'Görsel seçilemedi.');
      }
      return;
    }
    if (files.isEmpty) return;

    setState(() => _uploadingPhoto = true);
    try {
      final storage = ref.read(storageRepositoryProvider);
      for (final bytes in files) {
        if (_photos.length >= AppConstants.maxProductPhotos) break;
        if (bytes.length > AppConstants.maxPhotoSizeBytes) {
          if (mounted) {
            context.showError('Bir görsel 5 MB\'dan büyük; atlandı.');
          }
          continue;
        }
        // Jobs paritesi: product/{uid}/{ts}.jpg (3 segment — storage.rules).
        final handle = await storage.uploadImage(
          pathHint: 'product/${user.uid}',
          bytes: Uint8List.fromList(bytes),
        );
        if (!mounted) return;
        setState(() => _photos.add(handle));
      }
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      final denied = raw.contains('unauthorized') ||
          raw.contains('permission') ||
          raw.contains('403');
      context.showError(denied
          ? 'Fotoğraf yükleme izni yok. Storage kurallarını kontrol edin.'
          : 'Görsel yüklenemedi. Bağlantınızı kontrol edip tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _openPhotoPreview(int initialIndex) {
    if (_photos.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _ProductPhotoPreview(
          handles: List.of(_photos),
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _save({required bool publish}) async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.go(RoutePaths.login);
      return;
    }
    if (publish && !ref.read(productsLiveProvider)) {
      context.showError('Mağaza şu an kapalı; ürün yayınlanamaz.');
      return;
    }
    if (_categoryCode == null || _categoryCode!.isEmpty) {
      context.showError('Kategori seçin.');
      return;
    }
    final province = _province?.name ?? '';
    if (province.isEmpty) {
      context.showError('Listeden il seçin.');
      return;
    }
    if (publish && _photos.isEmpty) {
      context.showError('En az bir fotoğraf ekleyin.');
      return;
    }

    setState(() => _saving = true);
    final emailOk = await ensureEmailVerified(
      context,
      ref,
      actionLabel: publish ? 'ürün yayınlamak' : 'ürün kaydetmek',
    );
    if (!emailOk || !mounted) {
      setState(() => _saving = false);
      return;
    }

    final title = Validators.sanitizeFreeText(_title.text);
    final desc = Validators.sanitizeFreeText(_desc.text);
    final tags = _parseTags();
    final priceAmount = _parsePrice();
    final district = _district?.name;
    final now = DateTime.now();
    final repo = ref.read(productRepositoryProvider);

    try {
      if (_contentLocked && _productId != null) {
        final contentChanged = title != (_loaded?.title ?? '') ||
            desc != (_loaded?.description ?? '') ||
            _categoryCode != _loaded?.categoryCode ||
            !_listEq(_photos, _loaded?.photos ?? const []);

        await repo.updateSafeFields(
          productId: _productId!,
          priceType: _priceType,
          priceAmount: priceAmount,
          condition: _condition,
          quantity: _loaded?.quantity ?? 1,
          tags: tags,
          province: province,
          district: district,
          ownerName:
              user.displayName.isEmpty ? 'Usta' : user.displayName,
          ownerPhotoUrl: user.profilePhotoUrl,
        );

        if (contentChanged) {
          await repo.updateProductContent(
            productId: _productId!,
            title: title,
            description: desc,
            categoryCode: _categoryCode!,
            photos: List.of(_photos),
          );
          if (mounted) {
            context.showSuccess(
                'İçerik inceleme için gönderildi; Keşfet’te geçici gizlenir.');
          }
        } else if (mounted) {
          context.showSuccess('Kaydedildi.');
        }
      } else {
        // Tek yazma: yoksa create, varsa updateDraft (çift create+update yok).
        final product = Product(
          id: _productId ?? '',
          ownerUid: user.uid,
          ownerName:
              user.displayName.isEmpty ? 'Usta' : user.displayName,
          ownerPhotoUrl: user.profilePhotoUrl,
          title: title,
          description: desc,
          categoryCode: _categoryCode!,
          tags: tags,
          photos: List.of(_photos),
          priceType: _priceType,
          priceAmount: priceAmount,
          condition: _condition,
          province: province,
          district: district,
          status: ProductStatus.draft,
          createdAt: _loaded?.createdAt ?? now,
          updatedAt: now,
        );

        final String productId;
        if (_productId == null || _productId!.isEmpty) {
          productId = await repo.createDraft(product);
        } else {
          productId = _productId!;
          await repo.updateDraft(product.copyWith(updatedAt: now));
        }
        final saved = await repo.getProduct(productId);
        if (saved != null) {
          _applyProduct(saved);
        } else {
          _productId = productId;
        }

        if (publish) {
          // 2026-08-10: VİTRİN KAPISI KALKTI ("herkes satabilir").
          // Eskiden burada profil taslağı `.future` ile beklenip
          // `ShopCompletion` (meslek + bölge + profil fotoğrafı) kontrol
          // ediliyordu. O şart usta vitrinine aitti; usta olmayan biri
          // meslek seçmediği için ürün yayınlayamıyordu. Taslak okuma da
          // bu kontrolün tek müşterisiydi, o yüzden birlikte kaldırıldı.
          final fieldsComplete = productFieldsComplete(
            title: title,
            description: desc,
            categoryCode: _categoryCode!,
            photos: _photos,
            priceType: _priceType,
            priceAmount: priceAmount,
            province: province,
            condition: _condition,
          );
          final ok = canPublishProduct(
            userSuspended: user.suspended,
            fieldsComplete: fieldsComplete,
          );
          if (!ok) {
            if (mounted) {
              context.showError(_publishBlockedMessage(
                fieldsComplete: fieldsComplete,
                userSuspended: user.suspended,
              ));
            }
            setState(() => _saving = false);
            return;
          }
          await repo.publishProduct(productId);
          if (mounted) {
            context.showSuccess('Ürün Keşfet’te yayında 🎉');
            context.go(RoutePaths.myProducts);
            return;
          }
        } else if (mounted) {
          context.showSuccess('Taslak kaydedildi.');
        }
      }
    } catch (e, st) {
      AppLog.d('ÜRÜN KAYIT/YAYIN HATASI (publish=$publish): $e');
      AppLog.d('$st');
      if (mounted) {
        context.showError(_saveErrorMessage(e));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  /// Yayın engellendiğinde tam olarak neyin eksik olduğunu söyle.
  ///
  /// Vitrin (`ShopCompletion`) dalı 2026-08-10'da kaldırıldı: ürün koymak
  /// artık usta olmayı gerektirmiyor, dolayısıyla "önce vitrini tamamlayın"
  /// diyecek bir durum kalmadı.
  String _publishBlockedMessage({
    required bool fieldsComplete,
    required bool userSuspended,
  }) {
    if (userSuspended) {
      return 'Hesabınız askıda olduğu için ürün yayınlayamazsınız.';
    }
    if (!fieldsComplete) {
      return 'Taslak kaydedildi. Yayın için ürün alanları eksiksiz olmalı '
          '(başlık, açıklama, kategori, en az bir fotoğraf, il ve '
          'sabit/başlangıç fiyatı).';
    }
    return 'Taslak kaydedildi. Yayın koşulları sağlanmadı.';
  }

  String _saveErrorMessage(Object e) {
    // CF hatalarında kodu doğrudan oku (string aramadan güvenilir).
    if (e is FirebaseFunctionsException) {
      switch (e.code) {
        case 'unauthenticated':
          return 'Oturum/doğrulama gerekli. Çıkış yapıp tekrar girin '
              '(App Check kaydı da gerekebilir).';
        case 'permission-denied':
          return e.message?.isNotEmpty == true
              ? e.message!
              : 'Yayın izni yok.';
        case 'failed-precondition':
          return e.message?.isNotEmpty == true
              ? e.message!
              : 'Yayın koşulları sağlanmadı.';
        case 'resource-exhausted':
          return e.message?.isNotEmpty == true
              ? e.message!
              : 'Yayın limitine ulaşıldı.';
        case 'invalid-argument':
          return e.message ?? 'Geçersiz ürün verisi.';
        case 'not-found':
          return 'Yayın servisi bulunamadı (functions deploy gerekli).';
        case 'internal':
          return 'Sunucu hatası (App Check doğrulaması başarısız olabilir). '
              'Kod: internal — ${e.message ?? ''}';
        case 'unavailable':
          return 'Sunucuya ulaşılamadı. Bağlantınızı kontrol edin.';
        default:
          return 'Kayıt başarısız (${e.code}): ${e.message ?? ''}';
      }
    }
    final msg = e.toString();
    if (msg.contains('publish-cf-missing') ||
        msg.contains('content-cf-missing')) {
      return 'Yayın servisi henüz kurulu değil. Yönetici functions deploy etmeli.';
    }
    if (msg.contains('resource-exhausted') || msg.contains('Günlük')) {
      return 'Günlük yayın limitine ulaştınız.';
    }
    if (msg.contains('permission-denied') ||
        msg.contains('PERMISSION_DENIED')) {
      return 'Kayıt izni yok. E-posta doğrulaması ve oturumu kontrol edin.';
    }
    if (msg.contains('unauthenticated') || msg.contains('UNAUTHENTICATED')) {
      return 'Oturum gerekli. Tekrar giriş yapın.';
    }
    if (msg.contains('failed-precondition') ||
        msg.contains('fields-incomplete') ||
        msg.contains('FAILED_PRECONDITION')) {
      return 'Yayın koşulları sağlanmadı (alanlar veya vitrin eksik).';
    }
    if (msg.contains('not-draft') || msg.contains('product-not-found')) {
      return 'Ürün taslak değil veya bulunamadı. Listeyi yenileyip deneyin.';
    }
    if (msg.contains('not-found') && msg.contains('publish')) {
      return 'Yayın servisi bulunamadı (functions deploy gerekli).';
    }
    // Tanınmayan hata: ham metnin başını göster (teşhis için).
    final trimmed = msg.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
    final short = trimmed.length > 160 ? trimmed.substring(0, 160) : trimmed;
    return 'Kayıt başarısız: $short';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        appBar: GradientAppBar(title: 'Ürün'),
        body: LoadingView(),
      );
    }
    if (_loadFailed) {
      return Scaffold(
        appBar: const GradientAppBar(title: 'Ürün'),
        body: ErrorView(
          title: 'Yüklenemedi',
          message: 'Ürün bilgisi alınamadı. Bağlantınızı kontrol edin.',
          onRetry: () {
            setState(() {
              _loading = true;
              _loadFailed = false;
            });
            _bootstrap();
          },
        ),
      );
    }
    if (widget.productId != null && _loaded == null) {
      return const Scaffold(
        appBar: GradientAppBar(title: 'Ürün'),
        body: ErrorView(
          title: 'Bulunamadı',
          message: 'Bu ürün silinmiş veya erişilemiyor.',
        ),
      );
    }

    final palette = context.palette;

    // Geri tuşu: yığın varsa oraya (Ürünlerim / Mağaza), yoksa Ana Sayfa'ya.
    // Sarmalayıcı olmadan geri tuşu uygulamayı küçültüyordu.
    return MainTabScope(
      tab: MainTab.explore,
      child: Scaffold(
      appBar: GradientAppBar(
        title: _isNew && _productId == null ? 'Yeni ürün' : 'Ürünü düzenle',
        subtitle: _contentLocked
            ? 'İçerik değişince yeniden inceleme gerekir'
            : 'Taslak — yayınlayınca Keşfet’te görünür',
        icon: Icons.inventory_2_outlined,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: palette.card,
          border: Border(top: BorderSide(color: palette.hairline)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving
                      ? null
                      : () => _save(
                            // Taslak/yeni: yayınla. Yayındaki içerik
                            // güncellemesi: kaydet (yeniden inceleme).
                            publish: _status == ProductStatus.draft ||
                                _isNew,
                          ),
                  child: Text(
                    _saving
                        ? '…'
                        : (_status == ProductStatus.draft || _isNew)
                            ? 'Yayınla'
                            : 'Güncelle',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: ResponsiveCenter(
        maxWidth: 720,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_contentLocked)
                Material(
                  color: palette.infoSurface,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Durum: ${_status.labelTR}. Başlık/açıklama/foto '
                      'değişirse ürün yeniden inceleme kuyruğuna düşer.',
                      style: TextStyle(color: palette.info),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'Fotoğraflar',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Galeriden birden fazla seçebilirsiniz · dokunun: önizleme',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: palette.inkMuted,
                    ),
              ),
              const SizedBox(height: 8),
              // Kolaj: 3 sütun grid + ekle kutusu.
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _photos.length +
                    (_photos.length < AppConstants.maxProductPhotos &&
                            !_contentLocked
                        ? 1
                        : 0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, i) {
                  if (i >= _photos.length) {
                    return Material(
                      color: palette.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _uploadingPhoto || _contentLocked
                            ? null
                            : _pickPhoto,
                        child: Center(
                          child: _uploadingPhoto
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  Icons.add_a_photo_outlined,
                                  color: palette.primary,
                                ),
                        ),
                      ),
                    );
                  }
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Material(
                        color: palette.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _openPhotoPreview(i),
                          child: AppImage(
                            handle: _photos[i],
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      if (!_contentLocked)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: IconButton.filledTonal(
                            visualDensity: VisualDensity.compact,
                            iconSize: 16,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () =>
                                setState(() => _photos.removeAt(i)),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Başlık',
                  border: OutlineInputBorder(),
                ),
                maxLength: AppConstants.productTitleMax,
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.length < AppConstants.productTitleMin) {
                    return 'En az ${AppConstants.productTitleMin} karakter';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _desc,
                decoration: const InputDecoration(
                  labelText: 'Açıklama',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                maxLength: AppConstants.productDescMax,
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.length < AppConstants.productDescMin) {
                    return 'En az ${AppConstants.productDescMin} karakter';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // 144 meslek düz bir dropdown'da aranamıyordu; kullanıcı
              // listeyi kaydırarak bulmak zorundaydı. İlan formuyla aynı
              // aramalı + gruplu bileşene geçirildi (2026-08-10).
              _UrunKategoriSecici(
                value: _categoryCode,
                onChanged: (v) => setState(() => _categoryCode = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ProductCondition>(
                // ignore: deprecated_member_use
                value: _condition,
                decoration: const InputDecoration(
                  labelText: 'Durum',
                  border: OutlineInputBorder(),
                ),
                items: ProductCondition.values
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.labelTR),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _condition = v ?? _condition),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ProductPriceType>(
                // ignore: deprecated_member_use
                value: _priceType,
                decoration: const InputDecoration(
                  labelText: 'Fiyat tipi',
                  border: OutlineInputBorder(),
                ),
                items: ProductPriceType.values
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.labelTR),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _priceType = v ?? _priceType),
              ),
              if (_priceType != ProductPriceType.negotiable) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _price,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Fiyat (₺)',
                    border: OutlineInputBorder(),
                    hintText: 'ör. 1.500 veya 1.500,50',
                  ),
                  validator: (v) {
                    if (_priceType == ProductPriceType.negotiable) {
                      return null;
                    }
                    final n = Validators.parseTrAmount(v);
                    if (n == null || n <= 0) return 'Geçerli fiyat girin';
                    // Tavan: yanlışlıkla fazladan basamak girilen fiyat
                    // kart düzenini bozar ve müşteriyi kaçırır.
                    if (n > AppConstants.maxPriceAmount) {
                      return 'Fiyat çok yüksek (en fazla 100.000.000 ₺)';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _tags,
                decoration: const InputDecoration(
                  labelText: 'Etiketler (virgülle)',
                  border: OutlineInputBorder(),
                  hintText: 'ör. ahşap, özel kesim',
                ),
              ),
              const SizedBox(height: 12),
              ref.watch(provincesProvider).when(
                    loading: () =>
                        const LinearProgressIndicator(minHeight: 2),
                    error: (_, _) => Text(
                      'İl listesi yüklenemedi. Bağlantınızı kontrol edip '
                      'sayfayı yeniden açın.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: palette.danger),
                    ),
                    data: (provinces) => SearchableSelectField<Province>(
                      label: 'İl',
                      value: _province,
                      items: provinces,
                      itemLabel: (p) => p.name,
                      searchHint: 'İl ara…',
                      prefixIcon: Icons.location_city_outlined,
                      allowClear: false,
                      equals: (a, b) => a.id == b.id,
                      onSelected: (p) => setState(() {
                        _province = p;
                        _district = null; // il değişince ilçe sıfırlanır
                      }),
                    ),
                  ),
              const SizedBox(height: 12),
              if (_province == null)
                SearchableSelectField<District>(
                  label: 'İlçe (opsiyonel)',
                  value: null,
                  items: const [],
                  itemLabel: (d) => d.name,
                  prefixIcon: Icons.map_outlined,
                  enabled: false,
                  hint: 'Önce il seçin',
                  onSelected: (_) {},
                )
              else
                ref.watch(districtsProvider(_province!.id)).when(
                      loading: () =>
                          const LinearProgressIndicator(minHeight: 2),
                      error: (_, _) => Text(
                        'İlçe listesi yüklenemedi.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: palette.danger),
                      ),
                      data: (districts) => SearchableSelectField<District>(
                        label: 'İlçe (opsiyonel)',
                        value: _district,
                        items: districts,
                        itemLabel: (d) => d.name,
                        searchHint: 'İlçe ara…',
                        prefixIcon: Icons.map_outlined,
                        allowClear: true,
                        clearLabel: 'İlçe seçme (tüm il)',
                        onClear: () => setState(() => _district = null),
                        equals: (a, b) => a.id == b.id,
                        onSelected: (d) => setState(() => _district = d),
                      ),
                    ),
              const SizedBox(height: 20),
              // Satıcıya özgü uyarı: mevzuat sorumluluğu (vergi, fatura,
              // tüketici hakları) satıcıdadır — yayınlamadan önce görünür.
              DisclaimerNote.forFlow(DisclaimerFlow.urunYayinlama),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// Ürün kategorisi seçici — aramalı, kategoriye özgü.
///
/// Önce düz bir `DropdownButtonFormField` içinde **144 MESLEK** vardı.
/// İki ayrı sorun: (1) arama yoktu, kullanıcı kaydırarak buluyordu;
/// (2) liste HİZMET listesiydi — "Avukat", "Fizyoterapi", "Köpek
/// Gezdirme" altında ürün satmak anlamsız, üstelik "Boyacı" kategorisi
/// boya mı satıldığını yoksa boyacı mı arandığını belirsiz bırakıyordu.
///
/// Artık [ProductCategory]: ürünün KENDİSİNİ tarif eden 14 kategori.
/// Canlı ürün kategorisi listesi (adminConfig/productCategories).
///
/// MAĞAZA KATEGORİLERİYLE SINIRLI (2026-08-15): satıcı yalnız mağazasını
/// açarken seçtiği kategorilerde ürün paylaşabilir. Yapı malzemesi satan
/// birinin kozmetik yayınlaması hem vitrini hem Keşfet süzmesini bozardı.
///
/// ⚠️ TALEPLER BUNA TABİ DEĞİL: müşteri istediği kategoride ürün talebi
/// açabilir (`create_job_screen`, `kind=product`). Kısıt yalnız SATIŞ
/// tarafındadır.
///
/// Mağaza kategorisi yoksa (eski kayıt / henüz seçmemiş) liste tam kalır —
/// kullanıcıyı ürün ekleyemez hâle düşürmek yerine serbest bırakılır.
class _UrunKategoriSecici extends ConsumerWidget {
  const _UrunKategoriSecici({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = catalogOf(ref);
    final magazaKodlari = ref.watch(currentUserProvider)?.shopCategories ??
        const <String>[];

    // Mağaza kategorileri katalogdaki SIRAYA göre süzülür (kullanıcının
    // seçim sırası değil — liste her yerde aynı düzende görünsün).
    final izinli = magazaKodlari.isEmpty
        ? catalog.sirali
        : catalog.sirali.where(magazaKodlari.contains).toList();

    // Eski / pasif kod listede yoksa alan boşalmasın — eklenir. Bu, mağaza
    // kategorisi sonradan daraltılmış ürünler için de geçerlidir: mevcut
    // ürün düzenlenebilir kalır, yalnız YENİ seçim kısıtlanır.
    final kodlar = [
      ...izinli,
      if (value != null && value!.isNotEmpty && !izinli.contains(value!))
        value!,
    ];

    final alan = SearchableSelectField<String>(
      label: 'Kategori',
      value: value,
      items: kodlar,
      itemLabel: catalog.label,
      hint: 'Kategori seçin',
      searchHint: 'Kategori ara (örn. hırdavat, mobilya…)',
      prefixIcon: Icons.category_outlined,
      onSelected: onChanged,
    );

    // Kısıt GÖRÜNÜR olmalı: liste neden kısa, kullanıcı anlasın ve nereden
    // genişleteceğini bilsin. Açıklamasız kısıt "eksik kategori" hatası
    // olarak algılanır.
    if (magazaKodlari.isEmpty) return alan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        alan,
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: Text(
            'Yalnız mağaza kategorileriniz listelenir. '
            'Değiştirmek için: Profil > Mağaza > Düzenle.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.palette.inkMuted,
                  height: 1.3,
                ),
          ),
        ),
      ],
    );
  }
}

/// Ürün fotoğrafı tam ekran önizleme — X, boşluk veya geri ile kapanır.
class _ProductPhotoPreview extends StatefulWidget {
  const _ProductPhotoPreview({
    required this.handles,
    required this.initialIndex,
  });

  final List<String> handles;
  final int initialIndex;

  @override
  State<_ProductPhotoPreview> createState() => _ProductPhotoPreviewState();
}

class _ProductPhotoPreviewState extends State<_ProductPhotoPreview> {
  late final PageController _page =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _close() {
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.handles.length;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _close,
        ),
        title: total > 1
            ? Text(
                '${_index + 1} / $total',
                style: const TextStyle(fontWeight: FontWeight.w600),
              )
            : null,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _close,
        child: PageView.builder(
          controller: _page,
          itemCount: total,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) {
            return InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: GestureDetector(
                  // Fotoğrafa basınca kapanmasın; InteractiveViewer pan.
                  onTap: () {},
                  child: AppImage(
                    handle: widget.handles[i],
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
