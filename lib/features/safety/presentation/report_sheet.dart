import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/snackbar_helper.dart';
import '../../../data/models/report.dart';
import '../../auth/application/auth_controller.dart';
import '../data/safety_providers.dart';

/// Ortak şikayet sheet'i: neden seçimi + opsiyonel not → `reports` kuyruğuna
/// yazar. Mesaj, ilan ve kullanıcı şikayetlerinin tümü bunu kullanır.
/// Başarıda toast gösterir; gönderim başına hedef başına tek kayıt tutulur
/// (deterministik ID — tekrar şikayet mevcut kaydı günceller).
Future<void> showReportSheet(
  BuildContext context,
  WidgetRef ref, {
  required ReportTarget target,
  required String targetId,
  required String reportedUid,
  String? chatId,
}) async {
  final reporterUid = ref.read(currentUserProvider)?.uid;
  if (reporterUid == null) return;

  final result = await showModalBottomSheet<({ReportReason reason, String note})>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => _ReportSheet(target: target),
  );
  if (result == null || !context.mounted) return;

  try {
    await ref.read(reportRepositoryProvider).submitReport(
          reporterUid: reporterUid,
          reportedUid: reportedUid,
          target: target,
          targetId: targetId,
          chatId: chatId,
          reason: result.reason,
          note: result.note,
        );
    if (context.mounted) {
      context.showSuccess(
          'Şikayetiniz alındı. İncelenip gerekli işlem yapılacak.');
    }
  } catch (_) {
    if (context.mounted) {
      context.showError(
          'Şikayet gönderilemedi. Bağlantınızı kontrol edip tekrar deneyin.');
    }
  }
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.target});
  final ReportTarget target;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ReportReason? _reason;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String get _title => switch (widget.target) {
        ReportTarget.message => 'Mesajı Şikayet Et',
        ReportTarget.job => 'İlanı Şikayet Et',
        ReportTarget.user => 'Kullanıcıyı Şikayet Et',
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Klavye açılınca not alanı görünür kalsın.
      padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                'Şikayetiniz ekibimizce incelenir; gerekirse içerik kaldırılır '
                've kullanıcıya yaptırım uygulanır.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              RadioGroup<ReportReason>(
                groupValue: _reason,
                onChanged: (v) => setState(() => _reason = v),
                child: Column(
                  children: [
                    for (final r in ReportReason.values)
                      RadioListTile<ReportReason>(
                        value: r,
                        title: Text(r.labelTR,
                            style: const TextStyle(fontSize: 14)),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                maxLines: 3,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'Kısa açıklama (opsiyonel)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Şikayet Et'),
                  onPressed: _reason == null
                      ? null
                      : () => Navigator.pop(context,
                          (reason: _reason!, note: _noteController.text)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
