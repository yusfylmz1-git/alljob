import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cihaz bağlantı durumu — true = hiçbir ağ arayüzü yok (çevrimdışı).
///
/// Firestore çevrimdışında hata FIRLATMAZ: önbellekten sunar, önbellek boşsa
/// sessizce bekler (ekranda sonsuz yükleme dönebilir). Kullanıcı bunu
/// "uygulama takıldı" sanmasın diye uygulama genelinde ince bir şerit
/// gösterilir (bkz. [OfflineBannerHost]). Durum tespit edilemezse
/// (platform/izin sorunu) güvenli taraf seçilir: çevrimiçi say, şerit yok.
final isOfflineProvider = StreamProvider<bool>((ref) async* {
  bool offline(List<ConnectivityResult> results) =>
      results.isEmpty ||
      results.every((r) => r == ConnectivityResult.none);
  final connectivity = Connectivity();
  try {
    yield offline(await connectivity.checkConnectivity());
    await for (final results in connectivity.onConnectivityChanged) {
      yield offline(results);
    }
  } catch (_) {
    // Eklenti yok (test) / platform hatası → şerit gösterme.
    yield false;
  }
});

/// `MaterialApp.builder`'a takılan kabuk: içerik + çevrimdışıyken üstte
/// "İnternet bağlantısı yok" şeridi. Şerit dokunuşları YUTMAZ (bilgi amaçlı)
/// ve bağlantı dönünce kayarak kaybolur.
class OfflineBannerHost extends ConsumerWidget {
  const OfflineBannerHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(isOfflineProvider).valueOrNull ?? false;
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: SafeArea(
              minimum: const EdgeInsets.only(top: 6),
              child: AnimatedSlide(
                offset: offline ? Offset.zero : const Offset(0, -2.2),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: offline ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Center(
                    child: Material(
                      color: const Color(0xEE1F2937),
                      elevation: 4,
                      shadowColor: Colors.black38,
                      borderRadius: BorderRadius.circular(999),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.wifi_off_rounded,
                                size: 16, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'İnternet bağlantısı yok',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
