import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calculadora_bcv/controllers/rates_controller.dart';
import 'package:calculadora_bcv/models/rates_model.dart';
import 'package:calculadora_bcv/services/rates_service.dart';

void main() {
  final cachedJson = jsonEncode({
    'bcv': 10.0,
    'usdt': 10.0,
    'eur': 10.0,
    'updated_at': DateTime.now().toIso8601String(),
    'sources': <String, String>{},
  });

  final freshBody = jsonEncode({
    'bcv': 40.0,
    'usdt': 40.0,
    'eur': 40.0,
    'updated_at': DateTime.now().toIso8601String(),
    'sources': <String, String>{},
  });

  RatesController buildController({
    required http.Client client,
    bool online = true,
  }) {
    final service = RatesService(client: client, hasConnection: () async => online);
    return RatesController(service: service);
  }

  test('sin cache previo, load() deja las tasas frescas del servidor', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = buildController(
      client: MockClient((request) async => http.Response(freshBody, 200)),
    );

    await controller.load();

    expect(controller.rates?.bcv, 40.0);
    expect(controller.isOffline, false);
    expect(controller.isLoading, false);
  });

  test('con cache previo, lo muestra de inmediato y luego lo reemplaza con datos frescos',
      () async {
    SharedPreferences.setMockInitialValues({'cached_rates': cachedJson});
    final controller = buildController(
      client: MockClient((request) async => http.Response(freshBody, 200)),
    );

    final bcvPorNotificacion = <double?>[];
    controller.addListener(() => bcvPorNotificacion.add(controller.rates?.bcv));

    await controller.load();

    expect(bcvPorNotificacion.first, 10.0); // el cache se ve primero
    expect(bcvPorNotificacion.last, 40.0); // termina con el dato fresco
  });

  test('isLoading pasa por true durante el fetch y termina en false', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = buildController(
      client: MockClient((request) async => http.Response(freshBody, 200)),
    );

    final loadingPorNotificacion = <bool>[];
    controller.addListener(() => loadingPorNotificacion.add(controller.isLoading));

    await controller.load();

    expect(loadingPorNotificacion, contains(true));
    expect(controller.isLoading, false);
  });

  test('si la red falla pero hay cache, conserva el cache y marca offline', () async {
    SharedPreferences.setMockInitialValues({'cached_rates': cachedJson});
    final controller = buildController(
      client: MockClient((request) async => http.Response('error', 500)),
    );

    await controller.load();

    expect(controller.isOffline, true);
    expect(controller.rates?.bcv, 10.0); // se quedó con el valor del cache
  });

  test('si la red falla y no hay cache, rates queda null pero no explota', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = buildController(
      client: MockClient((request) async => http.Response('error', 500)),
    );

    await controller.load();

    expect(controller.rates, isNull);
    expect(controller.isOffline, true);
  });

  test('dotStatus es old si isOffline, aunque el cache en sí se vea "fresh" por su timestamp',
      () async {
    // El cache tiene updated_at = ahora mismo, así que Rates.status por sí
    // solo daría DataStatus.fresh. Pero como la red falló, no podemos
    // confirmar que ese dato sigue vigente.
    SharedPreferences.setMockInitialValues({'cached_rates': cachedJson});
    final controller = buildController(
      client: MockClient((request) async => http.Response('error', 500)),
    );

    await controller.load();

    expect(controller.rates!.status, DataStatus.fresh);
    expect(controller.dotStatus, DataStatus.old);
  });

  test('dotStatus refleja el status de rates cuando la red funciona', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = buildController(
      client: MockClient((request) async => http.Response(freshBody, 200)),
    );

    await controller.load();

    expect(controller.dotStatus, DataStatus.fresh);
  });
}
