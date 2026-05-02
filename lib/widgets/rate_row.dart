import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RateRow extends StatelessWidget {
  final String badge;       // "BCV", "USDT", "EUR"
  final String label;       // "Oficial", "Paralelo", "Euro"
  final Color badgeColor;
  final Color badgeBg;
  final double? resultBs;   // null mientras no hay monto ingresado
  final double rate;        // tasa base para mostrar como referencia

  const RateRow({
    super.key,
    required this.badge,
    required this.label,
    required this.badgeColor,
    required this.badgeBg,
    required this.rate,
    this.resultBs,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,##0.##', 'es_VE');

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131316),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1C1C20)),
      ),
      child: Row(
        children: [
          // Badge izquierda
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: badgeColor.withOpacity(0.3)),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: badgeColor,
                letterSpacing: 0.06,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Nombre
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF555555),
            ),
          ),
          const Spacer(),
          // Resultado
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                resultBs != null
                    ? '${formatter.format(resultBs)} Bs'
                    : '— Bs',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFE8E8E8),
                  fontFamily: 'monospace',
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                '@ ${formatter.format(rate)}',
                style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFF2E2E36),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
