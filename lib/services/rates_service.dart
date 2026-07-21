import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rates_model.dart';

class RatesService {
  RatesService({http.Client? client, Future<bool> Function()? hasConnection})
      : _client = client ?? http.Client(),
        _hasConnection = hasConnection ?? _defaultHasConnection;

  final http.Client _client;
  final Future<bool> Function() _hasConnection;

  static Future<bool> _defaultHasConnection() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  // IMPORTANTE: reemplazar con la URL real del Worker desplegado
  // Ejemplo: https://bcv-rates-worker.tuusuario.workers.dev/rates
  static const String _apiUrl =
      'https://bcv-rates-worker.y3lg.workers.dev/rates';
  static const String _cacheKey = 'cached_rates';

  // Devuelve las tasas del cache local (null si no hay nada guardado)
  Future<Rates?> getCachedRates() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return null;
    try {
      return Rates.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // Guarda tasas en cache local
  Future<void> _cacheRates(Rates rates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(rates.toJson()));
  }

  // Fetch desde el Worker, con reintentos y espera creciente ante fallos
  // transitorios (timeout, hiccup de red). Lanza excepción si se agotan
  // los intentos.
  Future<Rates> fetchFromNetwork({int retries = 2}) async {
    if (!await _hasConnection()) {
      throw Exception('Sin conexión');
    }
    for (var attempt = 0; ; attempt++) {
      try {
        final res = await _client
            .get(Uri.parse(_apiUrl))
            .timeout(const Duration(seconds: 8));

        if (res.statusCode != 200) {
          throw Exception('Error ${res.statusCode}');
        }

        final rates = Rates.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>,
        );

        await _cacheRates(rates);
        return rates;
      } catch (_) {
        if (attempt >= retries) rethrow;
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
  }
}
