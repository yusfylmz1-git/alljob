import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../data/models/favorite.dart';
import '../../auth/application/auth_controller.dart';
import '../data/favorite_providers.dart';

/// Takip et / bırak düğmesi — HERKES İÇİN (Instagram gibi).
///
/// Misafir dokununca girişe yönlenir; kimse kendini takip edemez.
/// Usta-özel alanlar (meslek/puan) İSTEĞE BAĞLI: sıradan bir kullanıcı
/// takip edilirken boş kalır, listede o satır çizilmez
/// ([Favorite.hasArtisanInfo]).
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({
    super.key,
    required this.artisanUid,
    required this.artisanName,
    this.professionNameTR = '',
    this.rating = 0,
    this.totalReviews = 0,
    this.photoUrl,
    this.filledBackground = false,
    this.compact = false,
  });

  /// Takip EDİLECEK kullanıcı (usta olmak zorunda değil).
  final String artisanUid;
  final String artisanName;

  /// Usta vitrini varsa doldurulur; yoksa boş.
  final String professionNameTR;
  final double rating;
  final int totalReviews;
  final String? photoUrl;

  /// true ise ikon beyaz daire zemin içinde gösterilir (hero üzerinde okunur).
  final bool filledBackground;

  /// true ise küçük, sıkı yerleşimli kalp (kart köşesi için).
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    // HERKES HERKESİ TAKİP EDER (2026-08-08). Eskiden usta modunda düğme
    // hiç görünmüyordu ("usta modunda favori kullanılmaz") — usta da usta
    // takip edebilmeli. Tek kısıt: kimse kendini takip edemez.
    if (user != null && user.uid == artisanUid) return const SizedBox.shrink();

    // Tek döküman dinle — tüm favori listesini her kartta çekme.
    final isFav = user == null
        ? false
        : (ref.watch(isFavoriteProvider(artisanUid)).valueOrNull ?? false);

    Future<void> onTap() async {
      if (user == null) {
        context.push(RoutePaths.login);
        return;
      }
      final fav = Favorite(
        customerUid: user.uid,
        artisanUid: artisanUid,
        artisanName: artisanName,
        professionNameTR: professionNameTR,
        rating: rating,
        totalReviews: totalReviews,
        photoUrl: photoUrl,
        // Takip EDENİN snapshot'ı — karşı tarafın "Takipçiler" listesi
        // hızlı görünsün diye. Takip, takip edilene adla görünür.
        customerName: user.displayName,
        customerPhotoUrl: user.profilePhotoUrl,
        createdAt: DateTime.now(),
      );
      try {
        final added = await ref.read(favoriteRepositoryProvider).toggle(fav);
        if (!context.mounted) return;
        context.showInfo(added ? 'Takip ediliyor.' : 'Takipten çıkarıldı.');
      } catch (_) {
        if (context.mounted) {
          context.showError('İşlem başarısız, tekrar deneyin.');
        }
      }
    }

    final icon = Icon(
      isFav ? Icons.favorite : Icons.favorite_border,
      color: isFav
          ? context.palette.danger
          // Beyaz daire zemin (aşağıda) temadan bağımsız — üzerindeki pasif
          // ikon da sabit koyu gri kalır (palette.inkMuted koyuda açılır).
          : (filledBackground ? const Color(0xFF475467) : null),
    );

    if (compact) {
      // Kart köşesi: küçük, beyaz yarı saydam daire içinde sıkı yerleşimli kalp.
      return Material(
        color: Colors.white.withValues(alpha: 0.9),
        shape: const CircleBorder(),
        elevation: 1,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              size: 18,
              // Yarı saydam beyaz daire üzerinde sabit koyu gri (tema bağımsız).
              color: isFav ? context.palette.danger : const Color(0xFF475467),
            ),
          ),
        ),
      );
    }

    if (filledBackground) {
      return Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 1,
        child: IconButton(
          icon: icon,
          tooltip: isFav ? 'Takipten çık' : 'Takip Et',
          onPressed: onTap,
        ),
      );
    }
    return IconButton(
      icon: icon,
      tooltip: isFav ? 'Takipten çık' : 'Takip Et',
      onPressed: onTap,
    );
  }
}
