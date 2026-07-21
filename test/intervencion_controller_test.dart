import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calculadora_bcv/controllers/intervencion_controller.dart';
import 'package:calculadora_bcv/models/intervencion_model.dart';
import 'package:calculadora_bcv/services/intervencion_service.dart';
import 'package:calculadora_bcv/services/notification_service.dart';

// Evita tocar el plugin real (que necesita un platform channel que no existe
// en test) y deja registrado qué se hubiera notificado.
class _FakeNotificationService extends NotificationService {
  final List<Intervencion> shown = [];

  @override
  Future<void> showIntervencionNotification(Intervencion intervencion) async {
    shown.add(intervencion);
  }
}

void main() {
  String bodyFor(String numero) => jsonEncode({
        'fecha': '21-07-2026',
        'numero': numero,
        'tasa_eur_bs': 840.71,
        'updated_at': DateTime.now().toIso8601String(),
      });

  IntervencionController buildController({
    required http.Client client,
    required _FakeNotificationService notifier,
  }) {
    final service = IntervencionService(client: client);
    return IntervencionController(service: service, notifier: notifier);
  }

  test('primera corrida (sin número previo guardado) no notifica, solo establece la base',
      () async {
    SharedPreferences.setMockInitialValues({});
    final notifier = _FakeNotificationService();
    final controller = buildController(
      client: MockClient((_) async => http.Response(bodyFor('020-26'), 200)),
      notifier: notifier,
    );

    await controller.check();

    expect(controller.intervencion?.numero, '020-26');
    expect(notifier.shown, isEmpty);

    final service = IntervencionService();
    expect(await service.getLastNotifiedNumero(), '020-26');
  });

  test('si el número cambió respecto al último notificado, dispara la notificación',
      () async {
    SharedPreferences.setMockInitialValues({
      'last_notified_intervencion': '019-26',
    });
    final notifier = _FakeNotificationService();
    final controller = buildController(
      client: MockClient((_) async => http.Response(bodyFor('020-26'), 200)),
      notifier: notifier,
    );

    await controller.check();

    expect(notifier.shown, hasLength(1));
    expect(notifier.shown.first.numero, '020-26');
  });

  test('si el número no cambió, no notifica de nuevo', () async {
    SharedPreferences.setMockInitialValues({
      'last_notified_intervencion': '020-26',
    });
    final notifier = _FakeNotificationService();
    final controller = buildController(
      client: MockClient((_) async => http.Response(bodyFor('020-26'), 200)),
      notifier: notifier,
    );

    await controller.check();

    expect(notifier.shown, isEmpty);
  });

  test('con cache previo lo muestra de inmediato antes de que llegue la red',
      () async {
    SharedPreferences.setMockInitialValues({
      'cached_intervencion': bodyFor('019-26'),
    });
    final notifier = _FakeNotificationService();
    final controller = buildController(
      client: MockClient((_) async => http.Response(bodyFor('020-26'), 200)),
      notifier: notifier,
    );

    final numerosPorNotificacion = <String?>[];
    controller.addListener(
        () => numerosPorNotificacion.add(controller.intervencion?.numero));

    await controller.check();

    expect(numerosPorNotificacion.first, '019-26');
    expect(numerosPorNotificacion.last, '020-26');
  });

  test('si la red falla, conserva el cache y no rompe', () async {
    SharedPreferences.setMockInitialValues({
      'cached_intervencion': bodyFor('019-26'),
    });
    final notifier = _FakeNotificationService();
    final controller = buildController(
      client: MockClient((_) async => http.Response('error', 500)),
      notifier: notifier,
    );

    await controller.check();

    expect(controller.intervencion?.numero, '019-26');
    expect(notifier.shown, isEmpty);
  });
}
