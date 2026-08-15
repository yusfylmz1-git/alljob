import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/app_constants.dart';
import '../theme/app_palette.dart';
import '../../core/utils/app_log.dart';

/// Uygulamadaki **tek** fotoğraf seçme + kırpma girişi.
///
/// ## Neden ortak
///
/// 2026-08-14 cihaz bulgusu: *"resimler eklendiğinde bazen yarım çıkıyor,
/// profil fotoğrafı yayık görünüyor."*
///
/// Kök neden bir çizim hatası değildi — **kırpma adımı hiç yoktu.** Kullanıcı
/// hangi oranda fotoğraf seçerse seçsin, kart onu `AspectRatio` +
/// `BoxFit.cover` ile zorla çerçeveye sığdırıyordu: dikey bir fotoğrafın
/// altı ve üstü kesiliyordu ("yarım"), geniş bir fotoğrafın kenarları
/// gidiyordu. Avatar da aynı sebeple kafayı ortalayamıyordu ("yayık").
///
/// Artık kullanıcı **yüklemeden önce** çerçeveyi kendisi seçiyor.
///
/// ⚠️ Yeni bir fotoğraf yükleme yeri eklersen `pickPhoto()` kullan;
/// doğrudan `ImagePicker().pickImage()` çağırma — kırpma atlanır ve aynı
/// hata geri döner.
///
/// ## Web notu
///
/// `image_cropper` web'de ek kurulum ister; burada web'de kırpma **atlanır**
/// ve fotoğraf olduğu gibi döner (uygulamanın ana hedefi mobil).
class PhotoPicker {
  const PhotoPicker._();

  /// Fotoğraf seçer, kırptırır ve **JPEG baytları** döndürür.
  /// Kullanıcı vazgeçerse `null`.
  ///
  /// [shape] kırpma çerçevesinin biçimini belirler:
  ///  - [PhotoShape.square] → 1:1 kilitli (profil fotoğrafı; avatar yuvarlak)
  ///  - [PhotoShape.portrait] → 4:5 kilitli (ürün / ilan görselleri)
  ///  - [PhotoShape.free] → serbest (sertifika/belge: metin kesilmesin)
  static Future<Uint8List?> pickPhoto(
    BuildContext context, {
    required ImageSource source,
    PhotoShape shape = PhotoShape.portrait,
    String title = 'Fotoğrafı ayarla',
  }) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      // Kırpmadan ÖNCE kabaca küçült: kırpıcı devasa bir bitmap'i belleğe
      // almasın (eski cihazlarda çökme sebebi).
      maxWidth: 2048,
      imageQuality: 92,
    );
    if (picked == null) return null;

    // Web: kırpıcı ek kurulum ister → olduğu gibi döndür.
    if (kIsWeb) return picked.readAsBytes();

    if (!context.mounted) return picked.readAsBytes();
    final cropped = await _crop(context, picked.path, shape, title);
    // Kırpma iptal edilirse fotoğrafı boşa düşürme: ham hâliyle devam et.
    if (cropped == null) return picked.readAsBytes();
    return cropped.readAsBytes();
  }

  /// Galeriden **çoklu** seçer ve her birini sırayla kırptırır.
  ///
  /// Kullanıcı bir fotoğrafın kırpmasını iptal ederse o fotoğraf **ham
  /// hâliyle** eklenir (seçimi boşa düşürmek sinir bozucu olurdu).
  /// Kaynak kamera ise tek fotoğrafa düşer.
  static Future<List<Uint8List>> pickMultiPhoto(
    BuildContext context, {
    required ImageSource source,
    required int limit,
    PhotoShape shape = PhotoShape.portrait,
    String title = 'Fotoğrafı ayarla',
  }) async {
    if (limit <= 0) return const [];

    final picker = ImagePicker();
    final List<XFile> secilen;
    if (source == ImageSource.gallery) {
      secilen = await picker.pickMultiImage(
        maxWidth: 2048,
        imageQuality: 92,
        limit: limit,
      );
    } else {
      final one = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 2048,
        imageQuality: 92,
      );
      secilen = one == null ? const [] : [one];
    }
    if (secilen.isEmpty) return const [];

    final sonuc = <Uint8List>[];
    for (var i = 0; i < secilen.length && i < limit; i++) {
      final f = secilen[i];
      if (kIsWeb) {
        sonuc.add(await f.readAsBytes());
        continue;
      }
      if (!context.mounted) break;
      // Birden fazla fotoğrafta kaçıncı olduğunu göster: kullanıcı arka
      // arkaya açılan kırpma ekranlarında kaybolmasın.
      final baslik = secilen.length > 1
          ? '$title (${i + 1}/${secilen.length})'
          : title;
      final cropped = await _crop(context, f.path, shape, baslik);
      sonuc.add(
        cropped == null ? await f.readAsBytes() : await cropped.readAsBytes(),
      );
    }
    return sonuc;
  }

  static Future<CroppedFile?> _crop(
    BuildContext context,
    String path,
    PhotoShape shape,
    String title,
  ) async {
    final palette = context.palette;
    try {
      return await ImageCropper().cropImage(
        sourcePath: path,
        // Son çıktı tavanı: Storage faturası + indirme hızı.
        maxWidth: AppConstants.imagePickMaxWidth.toInt(),
        maxHeight: (AppConstants.imagePickMaxWidth *
                (AppConstants.photoAspectHeight /
                    AppConstants.photoAspectWidth))
            .toInt(),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: AppConstants.imagePickImageQuality,
        aspectRatio: shape.ratio,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: title,
            toolbarColor: palette.primary,
            toolbarWidgetColor: Colors.white,
            backgroundColor: Colors.black,
            activeControlsWidgetColor: palette.primary,
            // Oran kilitliyse kullanıcı onu bozamasın: çerçeveyi kaydırıp
            // yakınlaştırabilir ama oranı değiştiremez.
            lockAspectRatio: shape != PhotoShape.free,
            hideBottomControls: shape != PhotoShape.free,
            initAspectRatio: CropAspectRatioPreset.original,
          ),
          IOSUiSettings(
            title: title,
            aspectRatioLockEnabled: shape != PhotoShape.free,
            resetAspectRatioEnabled: shape == PhotoShape.free,
            aspectRatioPickerButtonHidden: shape != PhotoShape.free,
            doneButtonTitle: 'Tamam',
            cancelButtonTitle: 'Vazgeç',
          ),
        ],
      );
    } catch (e) {
      // Kırpıcı açılamazsa (platform kanalı / bellek) akışı KESME:
      // çağıran taraf ham fotoğrafla devam eder.
      AppLog.d('PhotoPicker kırpma hatası: $e');
      return null;
    }
  }
}

/// Kırpma çerçevesinin biçimi.
enum PhotoShape {
  /// 1:1 — profil fotoğrafı. Avatar her yerde yuvarlak çizildiği için
  /// kare olmayan kaynak "yayık"/kaykılmış görünüyordu.
  square,

  /// 4:5 dikey — ürün ve ilan görselleri (kart ızgarasıyla aynı oran).
  portrait,

  /// Serbest — sertifika/belge. Zorunlu oran belgenin metnini keser.
  free;

  CropAspectRatio? get ratio => switch (this) {
        PhotoShape.square => const CropAspectRatio(ratioX: 1, ratioY: 1),
        PhotoShape.portrait => const CropAspectRatio(
            ratioX: AppConstants.photoAspectWidth,
            ratioY: AppConstants.photoAspectHeight,
          ),
        PhotoShape.free => null,
      };
}
