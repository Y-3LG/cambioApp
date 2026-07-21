import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/intervencion_model.dart';

class IntervencionService {
  IntervencionService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _apiUrl =
      'https://bcv-rates-worker.y3lg.workers.dev/intervencion';
  static const String _cacheKey = 'cached_intervencion';

  // Número de la última intervención que ya le mostramos al usuario (para no
  // notificar dos veces la misma, ni notificar la primera vez que se abre
  // la app con datos que ya venían del servidor de entrada).
  static const String _lastNotifiedKey = 'last_notified_intervencion';

  Future<Intervencion?> getCachedIntervencion() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return null;
    try {
      return Intervencion.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheIntervencion(Intervencion intervencion) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(intervencion.toJson()));
  }

  Future<String?> getLastNotifiedNumero() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastNotifiedKey);
  }

  Future<void> setLastNotifiedNumero(String numero) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastNotifiedKey, numero);
  }

  Future<Intervencion> fetchFromNetwork({int retries = 2}) async {
    for (var attempt = 0; ; attempt++) {
      try {
        final res = await _client
            .get(Uri.parse(_apiUrl))
            .timeout(const Duration(seconds: 8));

        if (res.statusCode != 200) {
          throw Exception('Error ${res.statusCode}');
        }

        final intervencion = Intervencion.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>,
        );

        await _cacheIntervencion(intervencion);
        return intervencion;
      } catch (_) {
        if (attempt >= retries) rethrow;
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
  }
}
