import 'package:flutter/foundation.dart';
import '../models/intervencion_model.dart';
import '../services/intervencion_service.dart';
import '../services/notification_service.dart';

// Muestra el cache local de inmediato (si hay) y luego busca la última
// intervención en el worker. Si el número cambió respecto a la última vez
// que ya le avisamos al usuario, dispara una notificación local. La primera
// vez que corre (sin nada guardado todavía) no notifica — solo establece la
// base de comparación, para no "avisar" de historial viejo al instalar.
class IntervencionController extends ChangeNotifier {
  IntervencionController({
    IntervencionService? service,
    NotificationService? notifier,
  })  : _service = service ?? IntervencionService(),
        _notifier = notifier ?? NotificationService();

  final IntervencionService _service;
  final NotificationService _notifier;

  Intervencion? _intervencion;
  Intervencion? get intervencion => _intervencion;

  Future<void> check() async {
    final cached = await _service.getCachedIntervencion();
    if (cached != null) {
      _intervencion = cached;
      notifyListeners();
    }

    final Intervencion fresh;
    try {
      fresh = await _service.fetchFromNetwork();
    } catch (_) {
      return;
    }

    _intervencion = fresh;
    notifyListeners();

    final lastNotified = await _service.getLastNotifiedNumero();
    if (lastNotified != null && lastNotified != fresh.numero) {
      await _notifier.showIntervencionNotification(fresh);
    }
    await _service.setLastNotifiedNumero(fresh.numero);
  }
}
