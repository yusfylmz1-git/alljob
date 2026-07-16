import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/storage/storage_repository.dart';

/// Hem uzak URL'leri (http) hem de mock `local://` handle'larını gösterebilen
/// görsel bileşeni. Platformdan bağımsız çalışır (Image.memory).
///
/// [memCacheWidth]/[memCacheHeight]: decode boyutunu sınırlar (avatar gibi
/// küçük yüzlerde büyük fotoğrafı full decode etmez → daha hızlı).
class AppImage extends ConsumerWidget {
  const AppImage({
    super.key,
    required this.handle,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.memCacheWidth,
    this.memCacheHeight,
    this.fadeInDuration = const Duration(milliseconds: 200),
    this.placeholder,
  });

  final String? handle;
  final BoxFit fit;
  final double? width;
  final double? height;

  /// Bellekte tutulan decode genişliği (px). Avatar için ~size * dpr önerilir.
  final int? memCacheWidth;
  final int? memCacheHeight;
  final Duration fadeInDuration;

  /// Özel placeholder (avatar baş harfi vb.); null ise gri kutu.
  final Widget? placeholder;

  /// http URL'yi disk/bellek önbelleğine ısıtır (sohbet listesi → thread).
  static void precacheHttp(BuildContext context, String? url) {
    if (url == null || url.isEmpty || !url.startsWith('http')) return;
    // ignore: discarded_futures
    precacheImage(CachedNetworkImageProvider(url), context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = handle;
    if (h == null || h.isEmpty) {
      return placeholder ?? _placeholder(context);
    }

    if (h.startsWith('local://')) {
      final bytes = ref.read(storageRepositoryProvider).localBytes(h);
      if (bytes == null) return placeholder ?? _placeholder(context);
      return Image.memory(bytes, fit: fit, width: width, height: height);
    }

    if (h.startsWith('http')) {
      // Diske önbelleğe alınır → aynı görsel her kaydırmada Storage'dan yeniden
      // inmez (bant genişliği/fatura tasarrufu).
      return CachedNetworkImage(
        imageUrl: h,
        fit: fit,
        width: width,
        height: height,
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
        fadeInDuration: fadeInDuration,
        fadeOutDuration: Duration.zero,
        placeholder: (_, _) => placeholder ?? _placeholder(context),
        errorWidget: (_, _, _) => placeholder ?? _placeholder(context),
      );
    }

    return placeholder ?? _placeholder(context);
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(Icons.image_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}

/// Yuvarlak profil avatarı — sohbet listesi / mesaj balonu / app bar.
/// Küçük mem-cache + kısa fade + baş harf placeholder → “geç yükleniyor”
/// hissini azaltır; liste ekranında [AppImage.precacheHttp] ile ısınır.
class AppAvatar extends ConsumerWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.photo,
    this.size = 40,
  });

  final String name;
  final String? photo;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cachePx = (size * dpr).round().clamp(48, 256);
    final letter = name.trim().isEmpty
        ? '?'
        : name.trim().substring(0, 1).toUpperCase();

    final letterFallback = Container(
      width: size,
      height: size,
      color: scheme.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: (photo == null || photo!.isEmpty)
            ? letterFallback
            : AppImage(
                handle: photo,
                width: size,
                height: size,
                fit: BoxFit.cover,
                memCacheWidth: cachePx,
                memCacheHeight: cachePx,
                // Önbellekten gelince anında; ağda kısa fade.
                fadeInDuration: const Duration(milliseconds: 80),
                placeholder: letterFallback,
              ),
      ),
    );
  }
}
