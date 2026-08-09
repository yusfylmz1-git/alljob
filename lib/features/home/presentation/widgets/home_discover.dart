import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../artisan/data/artisan_repository.dart' show ArtisanSummary;
import 'home_featured.dart' show oneChikanUstalarProvider;

/// Bir tarihin ISO hafta numarası (yıl içinde 1..53).
///
/// "Haftanın Ustası" rotasyonunun anahtarı. Sunucuya yazılan bir alan
/// GEREKMEZ: aynı hafta boyunca herkes aynı ustayı görür, hafta dönünce
/// liste kendiliğinden kayar.
int isoHaftaNo(DateTime t) {
  final d = DateTime.utc(t.year, t.month, t.day);
  // Perşembe kuralı: haftanın perşembesi hangi yıldaysa hafta o yıla aittir.
  final persembe = d.add(Duration(days: 4 - (d.weekday == 7 ? 7 : d.weekday)));
  final yilBasi = DateTime.utc(persembe.year, 1, 1);
  return ((persembe.difference(yilBasi).inDays) / 7).floor() + 1;
}

/// Haftanın ustasını seçer — HER HAFTA DEĞİŞİR.
///
/// Eskiden "en yüksek puanlı"nın `.first`i alınıyordu: puan değişmedikçe
/// AYNI usta sonsuza kadar kalıyordu, yani "Haftanın" sözü tutulmuyordu
/// (2026-08-10 kullanıcı bulgusu). Artık nitelikli adaylar arasında hafta
/// numarasına göre dönülür.
///
/// Aday havuzu bilinçli olarak dar: puan almamış usta "haftanın ustası"
/// olamaz. Havuz boşsa null → bölüm gizlenir.
ArtisanSummary? haftaninUstasiSec(List<ArtisanSummary> hepsi, DateTime now) {
  final adaylar = hepsi.where((u) => u.totalReviews > 0).toList()
    // Kararlı sıra: aynı hafta herkeste AYNI usta çıkmalı. Puan eşitse
    // uid'e göre ayrılır (liste sırası sunucudan değişebilir).
    ..sort((a, b) {
      final p = b.averageRating.compareTo(a.averageRating);
      return p != 0 ? p : a.uid.compareTo(b.uid);
    });
  if (adaylar.isEmpty) return null;
  return adaylar[isoHaftaNo(now) % adaylar.length];
}

/// Ana Sayfa "🔥 Bugün İlanda Hizmet'te" — haftanın ustası vitrini.
///
/// Sistem duyurusu BURADAN KALKTI (2026-08-10): duyuru bir keşif içeriği
/// değil; yeri Bildirimler ekranı. Ana sayfa vitrini yalnız usta gösterir.
class HomeDiscover extends ConsumerWidget {
  const HomeDiscover({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = context.palette;

    final ustalar = ref.watch(oneChikanUstalarProvider).valueOrNull ?? const [];
    final haftaninUstasi = haftaninUstasiSec(ustalar, DateTime.now());

    // Sistem duyurusu kartı KALKTI (2026-08-10): duyuru bir keşif içeriği
    // değil, bildirimdir — yeri Bildirimler ekranı. Ana sayfada vitrinin
    // ortasında durunca hem konu dışıydı hem yer kaplıyordu.
    if (haftaninUstasi == null) return const SizedBox.shrink();

    // TEK SATIR (2026-08-10): eskiden 150px yüksekliğinde yatay kayan
    // büyük kartlardı — tek usta için fazlasıyla yer kaplıyordu ve ana
    // sayfanın alt bölümlerini ekran dışına itiyordu.
    final rozet = const Color(0xFF2563EB);
    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () =>
            context.push(RoutePaths.artisanProfile(haftaninUstasi.uid)),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.hairline),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipOval(
                child: AppAvatar(
                  name: haftaninUstasi.displayName,
                  photo: haftaninUstasi.profilePhotoUrl,
                  size: 46,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.workspace_premium_rounded,
                            size: 14, color: rozet),
                        const SizedBox(width: 4),
                        Text(
                          'HAFTANIN USTASI',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: rozet,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      haftaninUstasi.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '⭐ ${haftaninUstasi.averageRating.toStringAsFixed(1)}'
                      ' · ${haftaninUstasi.professionNameTR}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: palette.inkMuted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: palette.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
