import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calculadora_bcv/services/rates_service.dart';

void main() {
  setUp(() {
    // shared_preferences no tiene disco real en test: esto simula un
    // almacenamiento vacío en memoria.
    SharedPreferences.setMockInitialValues({});
  });

  final validBody = jsonEncode({
    'bcv': 40.0,
    'usdt': 42.0,
    'eur': 44.0,
    'updated_at': DateTime.now().toIso8601String(),
    'sources': {'bcv': 'test', 'usdt': 'test', 'eur': 'test'},
  });

  test('fetchFromNetwork devuelve las tasas si el servidor responde 200 a la primera',
      () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response(validBody, 200);
    });
    final service = _buildService(client);

    final rates = await service.fetchFromNetwork();

    expect(rates.bcv, 40.0);
    expect(calls, 1);
  });

  test('fetchFromNetwork reintenta ante fallos transitorios y se recupera',
      () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      if (calls < 3) return http.Response('error', 500);
      return http.Response(validBody, 200);
    });
    final service = _buildService(client);

    final rates = await service.fetchFromNetwork(retries: 2);

    expect(rates.bcv, 40.0);
    expect(calls, 3); // falló 2 veces, tuvo éxito en el 3er intento
  });

  test('fetchFromNetwork lanza excepción si se agotan los reintentos',
      () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response('error', 500);
    });
    final service = _buildService(client);

    await expectLater(
      () => service.fetchFromNetwork(retries: 2),
      throwsException,
    );
    expect(calls, 3); // intento inicial + 2 reintentos, ninguno más
  });

  test('fetchFromNetwork exitoso guarda las tasas en cache', () async {
    final client = MockClient((request) async => http.Response(validBody, 200));
    final service = _buildService(client);

    await service.fetchFromNetwork();
    final cached = await service.getCachedRates();

    expect(cached, isNotNull);
    expect(cached!.bcv, 40.0);
  });

  test('getCachedRates devuelve null si nunca se guardó nada', () async {
    final client = MockClient((request) async => http.Response(validBody, 200));
    final service = _buildService(client);

    expect(await service.getCachedRates(), isNull);
  });

  test('fetchFromNetwork no intenta la red si no hay conexión', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response(validBody, 200);
    });
    final service = RatesService(
      client: client,
      hasConnection: () async => false,
    );

    await expectLater(
      () => service.fetchFromNetwork(),
      throwsException,
    );
    expect(calls, 0); // ni siquiera se intentó: nos ahorramos la espera
  });
}

RatesService _buildService(http.Client client) =>
    RatesService(client: client, hasConnection: () async => true);
