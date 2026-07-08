import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/storage/storage_repository.dart';

/// Hem uzak URL'leri (http) hem de mock `local://` handle'larını gösterebilen
/// görsel bileşeni. Platformdan bağımsız çalışır (Image.memory).
class AppImage extends ConsumerWidget {
  const AppImage({
    super.key,
    required this.handle,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  final String? handle;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = handle;
    if (h == null || h.isEmpty) {
      return _placeholder(context);
    }

    if (h.startsWith('local://')) {
      final bytes = ref.read(storageRepositoryProvider).localBytes(h);
      if (bytes == null) return _placeholder(context);
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
        placeholder: (_, _) => _placeholder(context),
        errorWidget: (_, _, _) => _placeholder(context),
      );
    }

    return _placeholder(context);
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
