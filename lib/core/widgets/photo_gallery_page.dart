import 'package:flutter/material.dart';

import 'app_image.dart';

/// Tam ekran fotoğraf galerisi — kaydır, yakınlaştır, çarpı veya geri ile kapat.
///
/// Rota değil: [Navigator.push] ile açılır; kapanınca alttaki sayfa
/// (profil, ilan, ürün) olduğu gibi kalır.
class PhotoGalleryPage extends StatefulWidget {
  const PhotoGalleryPage({
    super.key,
    required this.handles,
    this.initialIndex = 0,
  });

  final List<String> handles;
  final int initialIndex;

  /// Boş listede no-op. [initialIndex] taşarsa sıkıştırılır.
  static Future<void> open(
    BuildContext context, {
    required List<String> handles,
    int initialIndex = 0,
  }) {
    if (handles.isEmpty) return Future<void>.value();
    final i = initialIndex.clamp(0, handles.length - 1);
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PhotoGalleryPage(
          handles: List<String>.of(handles),
          initialIndex: i,
        ),
      ),
    );
  }

  @override
  State<PhotoGalleryPage> createState() => _PhotoGalleryPageState();
}

class _PhotoGalleryPageState extends State<PhotoGalleryPage> {
  late final PageController _page;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.handles.length - 1);
    _page = PageController(initialPage: _index);
  }

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
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Kapat',
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
      body: SafeArea(
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            PageView.builder(
              controller: _page,
              itemCount: total,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) {
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(
                    child: AppImage(
                      handle: widget.handles[i],
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
            if (total > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(total, (i) {
                    final active = i == _index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 10 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
