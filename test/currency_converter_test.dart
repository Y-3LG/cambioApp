import 'package:flutter_test/flutter_test.dart';
import 'package:calculadora_bcv/models/rates_model.dart';
import 'package:calculadora_bcv/utils/currency_converter.dart';

void main() {
  final rates = Rates(
    bcv: 40.0, // 1 USD = 40 BS
    usdt: 42.0, // 1 USDT = 42 BS
    eur: 44.0, // 1 EUR = 44 BS
    updatedAt: DateTime.now(),
    sources: const {},
  );

  group('toBS', () {
    test('convierte USD a BS usando la tasa bcv', () {
      expect(toBS(10, 'USD', rates), 400.0);
    });
    test('convierte USDT a BS usando la tasa usdt', () {
      expect(toBS(10, 'USDT', rates), 420.0);
    });
    test('convierte EUR a BS usando la tasa eur', () {
      expect(toBS(10, 'EUR', rates), 440.0);
    });
    test('BS a BS no cambia el monto', () {
      expect(toBS(10, 'BS', rates), 10.0);
    });
  });

  group('fromBS', () {
    test('convierte BS a USD dividiendo por bcv', () {
      expect(fromBS(400, 'USD', rates), 10.0);
    });
    test('devuelve 0 en vez de lanzar excepción si la tasa es 0', () {
      final ratesSinDatos = Rates(
        bcv: 0,
        usdt: 0,
        eur: 0,
        updatedAt: DateTime.now(),
        sources: const {},
      );
      expect(fromBS(100, 'USD', ratesSinDatos), 0.0);
    });
  });

  group('convert', () {
    test('USD -> EUR pasa correctamente por BS', () {
      // 10 USD = 400 BS = 400/44 EUR
      expect(convert(10, 'USD', 'EUR', rates), closeTo(9.0909, 0.001));
    });
    test('convertir a la misma moneda devuelve el mismo monto', () {
      expect(convert(25, 'USD', 'USD', rates), 25.0);
    });
    test('ida y vuelta (USD->BS->USD) recupera el monto original', () {
      final enBs = toBS(50, 'USD', rates);
      expect(fromBS(enBs, 'USD', rates), closeTo(50, 0.0001));
    });
  });

  group('formatAmount', () {
    test('cero se muestra como "0" sin decimales', () {
      expect(formatAmount(0), '0');
    });
    test('usa punto como separador de miles y coma como decimal', () {
      expect(formatAmount(1234.5), '1.234,5');
    });
    test('redondea a máximo 2 decimales', () {
      expect(formatAmount(10.126), '10,13');
    });
  });

  group('parseAmount', () {
    test('texto vacío devuelve null', () {
      expect(parseAmount(''), isNull);
    });
    test('texto no numérico devuelve null', () {
      expect(parseAmount('abc'), isNull);
    });
    test('formato venezolano "1.234,56" se interpreta como 1234.56', () {
      expect(parseAmount('1.234,56'), 1234.56);
    });
    test('número simple sin separadores', () {
      expect(parseAmount('500'), 500.0);
    });

    // El último separador (sea , o .) es siempre el decimal, sin importar
    // qué convención use quien escribe.
    test('coma como decimal sin separador de miles: "63,5"', () {
      expect(parseAmount('63,5'), 63.5);
    });
    test('punto como decimal (hábito de teclado en inglés): "63.5"', () {
      expect(parseAmount('63.5'), 63.5);
    });
    test('formato estadounidense "1,234.56" se interpreta como 1234.56', () {
      expect(parseAmount('1,234.56'), 1234.56);
    });
    test('varios separadores de miles con coma decimal: "1.234.567,89"', () {
      expect(parseAmount('1.234.567,89'), 1234567.89);
    });
    test('separador al final sin decimales: "63,"', () {
      expect(parseAmount('63,'), 63.0);
    });
  });
}
