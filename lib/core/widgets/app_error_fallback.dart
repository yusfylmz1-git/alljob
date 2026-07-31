import 'package:flutter/material.dart';

/// Release'te bir widget derleme hatasında Flutter'ın çizdiği boz gri kutu
/// yerine gösterilen sakin yedek görünüm (`ErrorWidget.builder`, main.dart).
///
/// Hatanın kendisi zaten `FlutterError.onError` üzerinden Crashlytics'e
/// raporlanır — buranın tek işi kullanıcıyı korkutmamaktır.
///
/// DİKKAT: Bu widget ağacın HERHANGİ bir yerinde, Directionality/Material/
/// Theme OLMADAN da çizilebilir (hata kökte olabilir). Bu yüzden hiçbir
/// ancestor'a güvenmez: kendi yönünü kurar, renkleri sabittir ve `FittedBox`
/// sayesinde en dar alanda bile taşma hatası üretmez (taşma hatası burada
/// olsaydı sonsuz döngüye girerdi).
class AppErrorFallback extends StatelessWidget {
  const AppErrorFallback({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFFF7F8FA),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFEDD5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.build_circle_outlined,
                      size: 32,
                      color: Color(0xFFEA580C),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Bir şeyler ters gitti',
                    style: TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Bu bölüm şu an gösterilemiyor.\n'
                    'Ekranı kapatıp yeniden deneyin; sorun sürerse\n'
                    'Yardım bölümünden bize bildirebilirsiniz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
