import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calculadora_bcv/services/intervencion_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final validBody = jsonEncode({
    'fecha': '21-07-2026',
    'numero': '020-26',
    'tasa_eur_bs': 840.71,
    'updated_at': DateTime.now().toIso8601String(),
  });

  test('fetchFromNetwork devuelve la intervención si el servidor responde 200',
      () async {
    final client = MockClient((request) async => http.Response(validBody, 200));
    final service = IntervencionService(client: client);

    final intervencion = await service.fetchFromNetwork();

    expect(intervencion.numero, '020-26');
    expect(intervencion.tasaEurBs, 840.71);
  });

  test('fetchFromNetwork reintenta ante fallos transitorios y se recupera',
      () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      if (calls < 3) return http.Response('error', 500);
      return http.Response(validBody, 200);
    });
    final service = IntervencionService(client: client);

    final intervencion = await service.fetchFromNetwork(retries: 2);

    expect(intervencion.numero, '020-26');
    expect(calls, 3);
  });

  test('fetchFromNetwork lanza excepción si se agotan los reintentos', () async {
    final client = MockClient((request) async => http.Response('error', 500));
    final service = IntervencionService(client: client);

    await expectLater(
      () => service.fetchFromNetwork(retries: 2),
      throwsException,
    );
  });

  test('fetchFromNetwork exitoso guarda la intervención en cache', () async {
    final client = MockClient((request) async => http.Response(validBody, 200));
    final service = IntervencionService(client: client);

    await service.fetchFromNetwork();
    final cached = await service.getCachedIntervencion();

    expect(cached, isNotNull);
    expect(cached!.numero, '020-26');
  });

  test('getCachedIntervencion devuelve null si nunca se guardó nada', () async {
    final service = IntervencionService(client: MockClient((_) async => http.Response('', 500)));
    expect(await service.getCachedIntervencion(), isNull);
  });

  test('el número notificado se guarda y se puede releer', () async {
    final service = IntervencionService(client: MockClient((_) async => http.Response('', 500)));

    expect(await service.getLastNotifiedNumero(), isNull);

    await service.setLastNotifiedNumero('019-26');

    expect(await service.getLastNotifiedNumero(), '019-26');
  });
}
