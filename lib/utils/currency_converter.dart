import 'package:intl/intl.dart';
import '../models/rates_model.dart';

// Convierte un monto en la moneda [desde] a bolívares (BS).
double toBS(double v, String desde, Rates r) {
  switch (desde) {
    case 'USD':
      return v * r.bcv;
    case 'USDT':
      return v * r.usdt;
    case 'EUR':
      return v * r.eur;
    default:
      return v;
  }
}

// Convierte un monto en bolívares (BS) a la moneda [hacia].
double fromBS(double v, String hacia, Rates r) {
  switch (hacia) {
    case 'USD':
      return r.bcv > 0 ? v / r.bcv : 0;
    case 'USDT':
      return r.usdt > 0 ? v / r.usdt : 0;
    case 'EUR':
      return r.eur > 0 ? v / r.eur : 0;
    default:
      return v;
  }
}

// Convierte un monto de la moneda [desde] a la moneda [hacia], vía BS.
double convert(double v, String desde, String hacia, Rates r) =>
    fromBS(toBS(v, desde, r), hacia, r);

// Formato venezolano: separador de miles '.', decimales ','.
String formatAmount(double v) {
  if (v == 0) return '0';
  return NumberFormat('#,##0.##', 'es_VE').format(v);
}

// Parsea un monto sin asumir un único formato: el ÚLTIMO separador
// (','  o '.') que aparece se interpreta como el decimal, y cualquier
// separador anterior se descarta (se asume de miles). Así "63.5", "63,5",
// "1.234,56" y "1,234.56" se leen todos correctamente, sin importar qué
// convención use quien escribe.
double? parseAmount(String text) {
  if (text.isEmpty) return null;
  final lastSeparator = text.lastIndexOf(RegExp(r'[.,]'));
  if (lastSeparator == -1) return double.tryParse(text);
  final entero = text.substring(0, lastSeparator).replaceAll(RegExp(r'[.,]'), '');
  final decimales = text.substring(lastSeparator + 1);
  return double.tryParse('$entero.$decimales');
}
