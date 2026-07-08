import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Salt-okunur yıldız puan göstergesi (yarım yıldız destekli).
class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key,
    required this.rating,
    this.size = 18,
    this.showValue = false,
  });

  final double rating;
  final double size;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 1; i <= 5; i++) _star(i),
        if (showValue) ...[
          const SizedBox(width: 6),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: size * 0.85,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _star(int position) {
    IconData icon;
    if (rating >= position) {
      icon = Icons.star_rounded;
    } else if (rating >= position - 0.5) {
      icon = Icons.star_half_rounded;
    } else {
      icon = Icons.star_outline_rounded;
    }
    return Icon(icon, size: size, color: AppColors.star);
  }
}
