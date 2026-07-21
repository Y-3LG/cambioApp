import 'package:flutter/material.dart';
import '../models/rates_model.dart';

class StatusDot extends StatelessWidget {
  final DataStatus status;
  final bool isLoading;

  const StatusDot({
    super.key,
    required this.status,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        width: 8,
        height: 8,
        child: CircularProgressIndicator(strokeWidth: 1.5),
      );
    }

    final color = switch (status) {
      DataStatus.fresh => const Color(0xFF1DB954),
      DataStatus.stale => const Color(0xFFFFB800),
      DataStatus.old => const Color(0xFFE53935),
    };

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)],
      ),
    );
  }
}
