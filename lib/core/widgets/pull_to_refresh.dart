import 'package:flutter/material.dart';

/// Kısa listelerde de aşağı çekerek yenilemeyi açar.
const kPullRefreshPhysics = AlwaysScrollableScrollPhysics();

/// [RefreshIndicator] sarmalayıcı — [child] kaydırılabilir olmalı.
class PullToRefresh extends StatelessWidget {
  const PullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: child,
    );
  }
}

/// Boş / kısa içerikte de pull-to-refresh (min yükseklik = ekran).
class RefreshableEmpty extends StatelessWidget {
  const RefreshableEmpty({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: kPullRefreshPhysics,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: child,
            ),
          );
        },
      ),
    );
  }
}

/// Provider yenileme sonrası bekleme; hata olsa da göstergesi kapanır.
Future<void> awaitRefresh(Future<void> Function() action) async {
  try {
    await action();
  } catch (_) {}
}
