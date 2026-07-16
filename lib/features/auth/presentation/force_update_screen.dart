import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_runtime_config.dart';
import '../../../core/config/app_version.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_palette.dart';

/// Eski/hatalı sürümleri kilitler (YOL_HARITASI: zorunlu güncelleme).
/// Admin `minAppVersion` ayarladığında, [kClientVersion] altındaysa gösterilir.
class ForceUpdateScreen extends ConsumerWidget {
  const ForceUpdateScreen({super.key});

  static const playStorePackageId = 'com.ustacepte.usta_cepte';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final min = ref.watch(appRuntimeConfigProvider).valueOrNull?.minAppVersion;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.system_update, size: 64, color: palette.primary),
              const SizedBox(height: 16),
              Text(
                'Güncelleme gerekli',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${AppConstants.appName}’in bu sürümü artık desteklenmiyor. '
                'Devam etmek için lütfen mağazadan güncelleyin.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: palette.inkMuted),
              ),
              const SizedBox(height: 16),
              Text(
                'Yüklü: $kClientVersion'
                '${min != null && min.isNotEmpty ? '  ·  Gerekli: $min+' : ''}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: palette.inkMuted),
              ),
              const SizedBox(height: 28),
              Text(
                'Play Store → “$playStorePackageId” aratın veya '
                'uygulama sayfasından Güncelle’ye basın.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: palette.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
