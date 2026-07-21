import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/intervencion_model.dart';

class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit),
    );

    // Android 13+ (API 33+) requiere pedir el permiso en runtime; en
    // versiones anteriores este método es un no-op que devuelve true.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> showIntervencionNotification(Intervencion intervencion) async {
    await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'intervencion_cambiaria',
        'Intervención cambiaria',
        channelDescription:
            'Avisa cuando el BCV publica una nueva intervención cambiaria',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(
      id: 0,
      title: 'Nueva intervención cambiaria del BCV',
      body:
          'Intervención ${intervencion.numero} — Bs. ${intervencion.tasaEurBs.toStringAsFixed(2)} por EUR',
      notificationDetails: details,
    );
  }
}
