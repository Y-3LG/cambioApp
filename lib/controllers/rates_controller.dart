import 'package:flutter/foundation.dart';
import '../models/rates_model.dart';
import '../services/rates_service.dart';

// Orquesta la carga de tasas: muestra el cache local de inmediato (si hay)
// y luego intenta traer datos frescos de red. Si la red falla, conserva lo
// último conocido y marca isOffline, en vez de dejar la pantalla en blanco.
class RatesController extends ChangeNotifier {
  RatesController({RatesService? service}) : _service = service ?? RatesService();

  final RatesService _service;

  Rates? _rates;
  Rates? get rates => _rates;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isOffline = false;
  bool get isOffline => _isOffline;

  // Si la última petición de red falló, el punto de estado siempre se
  // muestra "old" (aunque el cache en sí todavía se vea "fresh" por su
  // timestamp) porque no podemos confirmar que sigue vigente.
  DataStatus get dotStatus {
    if (_isOffline) return DataStatus.old;
    return _rates?.status ?? DataStatus.old;
  }

  Future<void> load() async {
    final cached = await _service.getCachedRates();
    if (cached != null) {
      _rates = cached;
      notifyListeners();
    }

    _isLoading = true;
    notifyListeners();
    try {
      _rates = await _service.fetchFromNetwork();
      _isOffline = false;
    } catch (_) {
      _isOffline = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
