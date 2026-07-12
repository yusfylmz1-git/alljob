import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../data/models/track_item.dart';
import '../../application/track_filter.dart';

/// Gelişmiş filtre + sıralama sayfasını açar. Kullanıcı "Uygula"ya basarsa yeni
/// [TrackFilter], kapatırsa null döner.
Future<TrackFilter?> showTrackFilterSheet(
  BuildContext context, {
  required TrackFilter current,
  required List<String> allTags,
}) {
  return showModalBottomSheet<TrackFilter>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _FilterSheet(initial: current, allTags: allTags),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial, required this.allTags});
  final TrackFilter initial;
  final List<String> allTags;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late TrackSort _sort = widget.initial.sort;
  late Set<TrackPriority> _priorities = {...widget.initial.priorities};
  late Set<String> _tags = {...widget.initial.tags};
  late bool _onlyReminders = widget.initial.onlyReminders;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Filtrele ve sırala',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      _sort = TrackSort.updatedDesc;
                      _priorities = {};
                      _tags = {};
                      _onlyReminders = false;
                    }),
                    child: const Text('Temizle'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _Label('Sıralama'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in TrackSort.values)
                    ChoiceChip(
                      label: Text(s.labelTR),
                      selected: _sort == s,
                      onSelected: (_) => setState(() => _sort = s),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _Label('Öncelik'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in TrackPriority.values)
                    FilterChip(
                      label: Text(p.labelTR),
                      selected: _priorities.contains(p),
                      onSelected: (on) => setState(() {
                        on ? _priorities.add(p) : _priorities.remove(p);
                      }),
                    ),
                ],
              ),
              if (widget.allTags.isNotEmpty) ...[
                const SizedBox(height: 20),
                _Label('Etiketler'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in widget.allTags)
                      FilterChip(
                        label: Text(t),
                        selected: _tags.contains(t),
                        onSelected: (on) => setState(() {
                          on ? _tags.add(t) : _tags.remove(t);
                        }),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Yalnız hatırlatması olanlar'),
                value: _onlyReminders,
                onChanged: (v) => setState(() => _onlyReminders = v),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    widget.initial.copyWith(
                      sort: _sort,
                      priorities: _priorities,
                      tags: _tags,
                      onlyReminders: _onlyReminders,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.primary,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Uygula'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: context.palette.inkMuted,
          ),
    );
  }
}
