import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/gradient_app_bar.dart';
import '../../../core/widgets/responsive_center.dart';
import '../legal_docs.dart';

/// Yasal metinler hub'ı (Profil → Yasal Metinler). Misafir de erişebilir
/// (kayıt ekranındaki onay linkleri buraya gelir).
class LegalHubScreen extends StatelessWidget {
  const LegalHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: const GradientAppBar(
        title: 'Yasal Metinler',
        icon: Icons.policy_outlined,
      ),
      body: ResponsiveCenter(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final doc in kLegalDocs) ...[
              Container(
                decoration: BoxDecoration(
                  color: palette.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.border),
                ),
                child: ListTile(
                  leading: Icon(Icons.description_outlined,
                      color: palette.inkMuted),
                  title: Text(doc.title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('Son güncelleme: $kLegalUpdated',
                      style: TextStyle(color: palette.inkMuted, fontSize: 12)),
                  trailing:
                      Icon(Icons.chevron_right, color: palette.inkFaint),
                  onTap: () => context.push(RoutePaths.legalDoc(doc.id)),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            Text(
              'Sorularınız için: $kLegalContactEmail',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: palette.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tek bir yasal metnin okunduğu sayfa (`/legal/{id}`).
class LegalDocScreen extends StatelessWidget {
  const LegalDocScreen({super.key, required this.docId});
  final String docId;

  @override
  Widget build(BuildContext context) {
    final doc = legalDocById(docId);
    final palette = context.palette;
    final theme = Theme.of(context);

    if (doc == null) {
      return Scaffold(
        appBar: const GradientAppBar(title: 'Yasal Metin'),
        body: const Center(child: Text('Aradığınız metin bulunamadı.')),
      );
    }

    return Scaffold(
      appBar: GradientAppBar(title: doc.title, icon: Icons.policy_outlined),
      body: SelectionArea(
        child: ResponsiveCenter(
          maxWidth: 720,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text('Son güncelleme: $kLegalUpdated',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: palette.inkMuted)),
              const SizedBox(height: 12),
              for (final section in doc.sections) ...[
                if (section.heading != null) ...[
                  const SizedBox(height: 12),
                  Text(section.heading!,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                ],
                Text(section.body,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
