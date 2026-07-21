import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../controllers/intervencion_controller.dart';
import '../controllers/rates_controller.dart';
import '../models/rates_model.dart';
import '../utils/currency_converter.dart' as converter;
import '../widgets/status_dot.dart';

// ─── Colores ──────────────────────────────────────────────────────────────────
const kBg = Color(0xFF0E0E0F);
const kCard = Color(0xFF131316);
const kBorder = Color(0xFF1C1C20);
const kTextMain = Color(0xFFE8E8E8);
const kTextSec = Color(0xFF555555);
const kTextDim = Color(0xFF2A2A35);
const kAccent = Color(0xFF3FB950);
const kRed = Color(0xFFE53935);
const kYellow = Color(0xFFFFB800);

// ─── Modelo de moneda ─────────────────────────────────────────────────────────
class Moneda {
  final String code;
  final String nombre;
  final String simbolo;
  final String bandera;
  final Color color;
  final Color fondo;
  final Color borde;
  const Moneda({
    required this.code,
    required this.nombre,
    required this.simbolo,
    required this.bandera,
    required this.color,
    required this.fondo,
    required this.borde,
  });
}

const _monedas = [
  Moneda(
    code: 'USD', nombre: 'Dólar americano', simbolo: '\$', bandera: '🇺🇸',
    color: Color(0xFFFFB800), fondo: Color(0xFF1E1A0E), borde: Color(0xFF2E2510),
  ),
  Moneda(
    code: 'BS', nombre: 'Bolívar venezolano', simbolo: 'Bs', bandera: '🇻🇪',
    color: Color(0xFF3FB950), fondo: Color(0xFF1A2A1A), borde: Color(0xFF1E3A1E),
  ),
  Moneda(
    code: 'USDT', nombre: 'Tether USDT', simbolo: '\$', bandera: '⬜',
    color: Color(0xFF26A17B), fondo: Color(0xFF1A2A22), borde: Color(0xFF1A3028),
  ),
  Moneda(
    code: 'EUR', nombre: 'Euro', simbolo: '€', bandera: '🇪🇺',
    color: Color(0xFF4F8EF7), fondo: Color(0xFF1A1F2E), borde: Color(0xFF1A2040),
  ),
];

Moneda _m(String code) =>
    _monedas.firstWhere((m) => m.code == code, orElse: () => _monedas[0]);

// USDT no es un país, así que no tiene bandera real: en vez del emoji
// placeholder ⬜, mostramos un círculo con su color de marca y el símbolo ₮.
Widget _bandera(Moneda m, double size) {
  if (m.code == 'USDT') {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: m.color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        '₮',
        style: TextStyle(
          fontSize: size * 0.62,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
  return Text(m.bandera, style: TextStyle(fontSize: size));
}

// ─── Conversión ───────────────────────────────────────────────────────────────
// La lógica real vive en lib/utils/currency_converter.dart (funciones públicas,
// testeables). Estos alias cortos evitan reescribir cada punto de uso abajo.
double _conv(double v, String desde, String hacia, Rates r) =>
    converter.convert(v, desde, hacia, r);

String _fmt(double v) => converter.formatAmount(v);

double? _parse(String text) => converter.parseAmount(text);

// ─────────────────────────────────────────────────────────────────────────────
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});
  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen>
    with TickerProviderStateMixin {
  final _controller = RatesController();
  final _intervencionController = IntervencionController();

  String _desde = 'USD';
  String _hacia = 'BS';

  final _ctrlDesde = TextEditingController();
  final _ctrlHacia = TextEditingController();
  final _focusDesde = FocusNode();
  final _focusHacia = FocusNode();

  bool _editingTop = true;
  bool _lock = false;

  late final AnimationController _swapCtrl;
  late final AnimationController _equivCtrl;
  late final Animation<double> _equivOpacity;
  late final Animation<Offset> _equivSlide;

  final Map<String, bool> _copiado = {};

  @override
  void initState() {
    super.initState();

    _swapCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));

    _equivCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _equivOpacity =
        CurvedAnimation(parent: _equivCtrl, curve: Curves.easeOut);
    _equivSlide = Tween<Offset>(
            begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _equivCtrl, curve: Curves.easeOut));

    _focusDesde.addListener(() {
      if (_focusDesde.hasFocus && mounted) setState(() => _editingTop = true);
    });
    _focusHacia.addListener(() {
      if (_focusHacia.hasFocus && mounted) setState(() => _editingTop = false);
    });

    _controller.addListener(_onRatesChanged);
    _controller.load();
    // No engancha nada visual todavía: chequea en silencio y, si el número
    // de intervención cambió desde la última vez, dispara una notificación
    // local (ver IntervencionController).
    _intervencionController.check();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusDesde.requestFocus());
  }

  @override
  void dispose() {
    // RatesController no se dispone acá a propósito: si load() sigue en
    // vuelo cuando la pantalla se destruye, un notifyListeners() tardío
    // sobre un ChangeNotifier ya dispuesto lanza una excepción. No maneja
    // recursos propios (no hay streams/timers), así que dejarlo vivir hasta
    // que el garbage collector lo recoja es seguro.
    _controller.removeListener(_onRatesChanged);
    _swapCtrl.dispose();
    _equivCtrl.dispose();
    _ctrlDesde.dispose();
    _ctrlHacia.dispose();
    _focusDesde.dispose();
    _focusHacia.dispose();
    super.dispose();
  }

  // ── Tasas ──────────────────────────────────────────────────────────────────
  void _onRatesChanged() {
    if (!mounted) return;
    setState(() {});
    _recalc();
  }

  // ── Cálculo ────────────────────────────────────────────────────────────────
  void _recalc() {
    final rates = _controller.rates;
    if (rates == null || _lock) return;
    _lock = true;
    if (_editingTop) {
      final v = _parse(_ctrlDesde.text);
      _ctrlHacia.text = v != null ? _fmt(_conv(v, _desde, _hacia, rates)) : '';
    } else {
      final v = _parse(_ctrlHacia.text);
      _ctrlDesde.text = v != null ? _fmt(_conv(v, _hacia, _desde, rates)) : '';
    }
    _lock = false;
    final monto = _parse(_editingTop ? _ctrlDesde.text : _ctrlHacia.text);
    if (monto != null && monto > 0) {
      _equivCtrl.forward();
    } else {
      _equivCtrl.reverse();
    }
    setState(() {});
  }

  // ── Swap ───────────────────────────────────────────────────────────────────
  void _swap() {
    if (_swapCtrl.isAnimating) return;
    _swapCtrl.forward().then((_) => _swapCtrl.reverse());
    final valorAbajo = _ctrlHacia.text;
    setState(() {
      final tmp = _desde; _desde = _hacia; _hacia = tmp;
      _ctrlDesde.text = valorAbajo;
      _editingTop = true;
    });
    _recalc();
    _focusDesde.requestFocus();
  }

  // ── Selector de moneda ─────────────────────────────────────────────────────
  void _seleccionar(bool esDesde) {
    final excluir = esDesde ? _hacia : _desde;
    final opciones = _monedas.where((m) => m.code != excluir).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: kBorder,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('SELECCIONAR MONEDA',
                style: TextStyle(fontSize: 10, color: kTextSec, letterSpacing: 0.12)),
            const SizedBox(height: 12),
            ...opciones.map((m) {
              final sel = esDesde ? _desde : _hacia;
              final isSelected = m.code == sel;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (esDesde) {
                      _desde = m.code;
                    } else {
                      _hacia = m.code;
                    }
                  });
                  Navigator.pop(context);
                  _recalc();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? m.fondo : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: isSelected ? m.borde : Colors.transparent),
                  ),
                  child: Row(
                    children: [
                      _bandera(m, 20),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.code,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? m.color : kTextMain)),
                          Text(m.nombre,
                              style: const TextStyle(
                                  fontSize: 11, color: kTextSec)),
                        ],
                      ),
                      const Spacer(),
                      if (isSelected)
                        Icon(Icons.check_rounded, color: m.color, size: 18),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Copia ──────────────────────────────────────────────────────────────────
  void _copiar(String key, String valor) {
    final limpio = valor.replaceAll('.', '').replaceAll(',', '.');
    Clipboard.setData(ClipboardData(text: limpio));
    setState(() => _copiado[key] = true);
    Future.delayed(const Duration(milliseconds: 600),
        () { if (mounted) setState(() => _copiado[key] = false); });
  }

  // ── Helpers de UI ──────────────────────────────────────────────────────────
  String _tasaRef() {
    final rates = _controller.rates;
    if (rates == null) return 'Cargando...';
    final tasa = _conv(1, _desde, _hacia, rates);
    return '1 ${_m(_desde).code} = ${_fmt(tasa)} ${_m(_hacia).code}';
  }

  String _timestamp() {
    final rates = _controller.rates;
    if (rates == null) return '';
    final age = rates.ageMinutes;
    if (_controller.isOffline) {
      final h = DateFormat('HH:mm').format(rates.updatedAt.toLocal());
      return 'Sin conexion · datos de $h';
    }
    if (age < 1) return 'Actualizado ahora';
    if (age < 60) return 'Actualizado hace ${age}m';
    return 'Hace ${(age / 60).floor()}h';
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            // En pantallas anchas (web de escritorio) evita que la app se
            // estire de punta a punta; en celular esto nunca se activa
            // porque el viewport ya es más angosto que 480.
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _zona1(),
                        _zona2(),
                        _zona3(),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
                _footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // ZONA 1 — Conversión
  // ────────────────────────────────────────────────────────────────────────────
  Widget _zona1() {
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _lbl('CONVIERTES'),
          const SizedBox(height: 8),
          _campo(_ctrlDesde, _focusDesde, _desde, true,
              (v) { _editingTop = true; _recalc(); }),
          const SizedBox(height: 14),
          Center(
            child: AnimatedBuilder(
              animation: _swapCtrl,
              builder: (_, child) => Transform.rotate(
                angle: _swapCtrl.value * 3.14159,
                child: child,
              ),
              child: GestureDetector(
                onTap: _swap,
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: kAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: kAccent.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: const Icon(Icons.swap_vert_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _lbl('RECIBES'),
          const SizedBox(height: 8),
          _campo(_ctrlHacia, _focusHacia, _hacia, false,
              (v) { _editingTop = false; _recalc(); }),
          const SizedBox(height: 12),
          Container(height: 1, color: kBorder),
          const SizedBox(height: 10),
          Center(
            child: Text(
              _tasaRef(),
              style: const TextStyle(
                  fontSize: 11, color: kTextSec, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lbl(String t) => Text(t,
      style: const TextStyle(
          fontSize: 10, color: Color(0xFF444444), letterSpacing: 0.1));

  Widget _campo(
    TextEditingController ctrl,
    FocusNode focus,
    String code,
    bool esDesde,
    ValueChanged<String> onChange,
  ) {
    final moneda = _m(code);
    return AnimatedBuilder(
      animation: focus,
      builder: (_, __) {
        final active = focus.hasFocus;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: kBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: active ? kAccent : kBorder, width: active ? 1.5 : 1),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _seleccionar(esDesde),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E24),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2A2A35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _bandera(moneda, 14),
                      const SizedBox(width: 5),
                      Text(moneda.code,
                          style: const TextStyle(
                              fontSize: 13,
                              color: kTextMain,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 14, color: kTextSec),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  focusNode: focus,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: kTextMain,
                      fontFamily: 'monospace'),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '0',
                    hintStyle: TextStyle(
                        color: Color(0xFF2A2A2A),
                        fontSize: 28,
                        fontFamily: 'monospace'),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: onChange,
                ),
              ),
              const SizedBox(width: 6),
              Text(moneda.simbolo,
                  style: const TextStyle(fontSize: 14, color: kTextSec)),
            ],
          ),
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // ZONA 2 — También equivale a
  // ────────────────────────────────────────────────────────────────────────────
  Widget _zona2() {
    final rates = _controller.rates;
    final montoSrc =
        _parse(_editingTop ? _ctrlDesde.text : _ctrlHacia.text);
    final monedaSrc = _editingTop ? _desde : _hacia;
    final otras =
        _monedas.where((m) => m.code != _desde && m.code != _hacia).toList();

    // SizeTransition colapsa el alto a 0 (no solo la opacidad) para que
    // "TASAS DE REFERENCIA" suba y no quede un hueco vacío cuando no hay
    // ningún monto cargado.
    return SizeTransition(
      sizeFactor: _equivCtrl,
      alignment: const Alignment(-1, -1),
      child: FadeTransition(
        opacity: _equivOpacity,
        child: SlideTransition(
          position: _equivSlide,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text('TAMBIÉN EQUIVALE A',
                style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF444444),
                    letterSpacing: 0.1)),
            const SizedBox(height: 10),
            ...otras.map((m) {
              final resultado =
                  (rates != null && montoSrc != null && montoSrc > 0)
                      ? _conv(montoSrc, monedaSrc, m.code, rates)
                      : null;
              final valorStr =
                  resultado != null ? _fmt(resultado) : '—';
              final copiado = _copiado[m.code] == true;
              return GestureDetector(
                onTap: () {
                  if (resultado != null) _copiar(m.code, valorStr);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: kCard,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: copiado ? kAccent : kBorder),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: m.fondo,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: m.borde),
                            ),
                            child: Text(m.code,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: m.color,
                                    fontFamily: 'monospace')),
                          ),
                          const SizedBox(height: 4),
                          Text(m.nombre,
                              style: const TextStyle(
                                  fontSize: 10, color: kTextSec)),
                        ],
                      ),
                      const Spacer(),
                      if (copiado)
                        const Text('Copiado ✓',
                            style: TextStyle(
                                fontSize: 13,
                                color: kAccent,
                                fontFamily: 'monospace'))
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(valorStr,
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    color: kTextMain,
                                    fontFamily: 'monospace')),
                            const SizedBox(width: 4),
                            Text(m.simbolo,
                                style: const TextStyle(
                                    fontSize: 12, color: kTextSec)),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            }),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // ZONA 3 — Tasas del día
  // ────────────────────────────────────────────────────────────────────────────
  Widget _zona3() {
    final rates = _controller.rates;
    final filas = [
      (_m('USD'), rates?.bcv, 'USD', 'bcv'),
      (_m('USDT'), rates?.usdt, 'USDT', 'usdt'),
      (_m('EUR'), rates?.eur, 'EUR', 'eur'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text('TASAS DE REFERENCIA',
            style: TextStyle(
                fontSize: 10,
                color: Color(0xFF444444),
                letterSpacing: 0.1)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder),
          ),
          child: Column(
            children: filas.asMap().entries.map((e) {
              final idx = e.key;
              final (moneda, tasa, code, sourceKey) = e.value;
              final esUltima = idx == filas.length - 1;
              final copiado = _copiado['tasa_$code'] == true;
              final tasaStr = tasa != null ? _fmt(tasa) : '—';
              final fuente = rates?.sources[sourceKey];
              return GestureDetector(
                onLongPress: () {
                  if (tasa != null) _copiar('tasa_$code', tasaStr);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: esUltima
                          ? BorderSide.none
                          : const BorderSide(color: kBorder),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: moneda.fondo,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: moneda.borde),
                          ),
                          child: Text(moneda.code,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: moneda.color,
                                  fontFamily: 'monospace')),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(moneda.nombre,
                                  style: const TextStyle(
                                      fontSize: 11, color: kTextSec)),
                              if (fuente != null)
                                Text(fuente,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 9, color: kTextDim)),
                            ],
                          ),
                        ),
                        if (copiado)
                          const Text('Copiado ✓',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: kAccent,
                                  fontFamily: 'monospace'))
                        else ...[
                          Text('$tasaStr Bs',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: kTextMain,
                                  fontFamily: 'monospace')),
                          const SizedBox(width: 6),
                          Text('por 1 $code',
                              style: const TextStyle(
                                  fontSize: 10, color: kTextSec)),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        const Center(
          child: Text(
            'Tasas de referencia. No constituyen oferta financiera.',
            style: TextStyle(fontSize: 9, color: kTextDim),
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // ZONA 4 — Footer
  // ────────────────────────────────────────────────────────────────────────────
  Widget _footer() {
    final status = _controller.dotStatus;
    final isOffline = _controller.isOffline;
    Color tsColor = kTextDim;
    if (isOffline) tsColor = kRed;
    if (!isOffline && status == DataStatus.old) tsColor = kYellow;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      decoration: const BoxDecoration(
        color: kBg,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(_timestamp(),
              style: TextStyle(
                  fontSize: 9, color: tsColor, fontFamily: 'monospace')),
          StatusDot(status: status, isLoading: _controller.isLoading),
        ],
      ),
    );
  }
}
