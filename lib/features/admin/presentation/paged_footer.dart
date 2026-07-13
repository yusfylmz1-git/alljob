import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';

/// Sayfalı listelerin altındaki ortak "daha fazla" alanı: yükleniyorsa spinner,
/// daha varsa "Daha fazla yükle" butonu, yoksa "sonu" ibaresi.
class PagedFooter extends StatelessWidget {
  const PagedFooter({
    super.key,
    required this.hasMore,
    required this.loadingMore,
    required this.onLoadMore,
    this.endLabel = 'Kuyruğun sonu',
  });

  final bool hasMore;
  final bool loadingMore;
  final VoidCallback onLoadMore;
  final String endLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Center(
        child: loadingMore
            ? const Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : hasMore
                ? OutlinedButton.icon(
                    onPressed: onLoadMore,
                    icon: const Icon(Icons.expand_more_rounded, size: 18),
                    label: const Text('Daha fazla yükle'),
                  )
                : Text(endLabel,
                    style: TextStyle(color: palette.inkFaint, fontSize: 12)),
      ),
    );
  }
}
