import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/rates_model.dart';
import '../services/rates_service.dart';
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

// ─── Conversión ───────────────────────────────────────────────────────────────
double _toBS(double v, String desde, Rates r) {
  switch (desde) {
    case 'USD': return v * r.bcv;
    case 'USDT': return v * r.usdt;
    case 'EUR': return v * r.eur;
    default: return v;
  }
}

double _fromBS(double v, String hacia, Rates r) {
  switch (hacia) {
    case 'USD': return r.bcv > 0 ? v / r.bcv : 0;
    case 'USDT': return r.usdt > 0 ? v / r.usdt : 0;
    case 'EUR': return r.eur > 0 ? v / r.eur : 0;
    default: return v;
  }
}

double _conv(double v, String desde, String hacia, Rates r) =>
    _fromBS(_toBS(v, desde, r), hacia, r);

// ─── Formato venezolano ───────────────────────────────────────────────────────
String _fmt(double v) {
  if (v == 0) return '0';
  return NumberFormat('#,##0.##', 'es_VE').format(v);
}

double? _parse(String text) {
  if (text.isEmpty) return null;
  return double.tryParse(text.replaceAll('.', '').replaceAll(',', '.'));
}

// ─────────────────────────────────────────────────────────────────────────────
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});
  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen>
    with TickerProviderStateMixin {
  final _service = RatesService();
  Rates? _rates;
  bool _isLoading = false;
  bool _isOffline = false;

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

    _loadRates();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusDesde.requestFocus());
  }

  @override
  void dispose() {
    _swapCtrl.dispose();
    _equivCtrl.dispose();
    _ctrlDesde.dispose();
    _ctrlHacia.dispose();
    _focusDesde.dispose();
    _focusHacia.dispose();
    super.dispose();
  }

  // ── Tasas ──────────────────────────────────────────────────────────────────
  Future<void> _loadRates() async {
    final cached = await _service.getCachedRates();
    if (cached != null && mounted) {
      setState(() => _rates = cached);
      _recalc();
    }
    setState(() => _isLoading = true);
    try {
      final fresh = await _service.fetchFromNetwork();
      if (mounted) setState(() { _rates = fresh; _isOffline = false; });
      _recalc();
    } catch (_) {
      if (mounted) setState(() => _isOffline = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Cálculo ────────────────────────────────────────────────────────────────
  void _recalc() {
    if (_rates == null || _lock) return;
    _lock = true;
    if (_editingTop) {
      final v = _parse(_ctrlDesde.text);
      _ctrlHacia.text = v != null ? _fmt(_conv(v, _desde, _hacia, _rates!)) : '';
    } else {
      final v = _parse(_ctrlHacia.text);
      _ctrlDesde.text = v != null ? _fmt(_conv(v, _hacia, _desde, _rates!)) : '';
    }
    _lock = false;
    final monto = _parse(_editingTop ? _ctrlDesde.text : _ctrlHacia.text);
    if (monto != null && monto > 0) _equivCtrl.forward();
    else _equivCtrl.reverse();
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
                    if (esDesde) _desde = m.code;
                    else _hacia = m.code;
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
                      Text(m.bandera, style: const TextStyle(fontSize: 20)),
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
    if (_rates == null) return 'Cargando...';
    final tasa = _conv(1, _desde, _hacia, _rates!);
    return '1 ${_m(_desde).code} = ${_fmt(tasa)} ${_m(_hacia).code}';
  }

  String _timestamp() {
    if (_rates == null) return '';
    final age = _rates!.ageMinutes;
    if (_isOffline) {
      final h = DateFormat('HH:mm').format(_rates!.updatedAt.toLocal());
      return 'Sin conexion · datos de $h';
    }
    if (age < 1) return 'Actualizado ahora';
    if (age < 60) return 'Actualizado hace ${age}m';
    return 'Hace ${(age / 60).floor()}h';
  }

  DataStatus _dotStatus() {
    if (_isOffline) return DataStatus.old;
    return _rates?.status ?? DataStatus.old;
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
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
                          color: kAccent.withOpacity(0.35),
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
                      Text(moneda.bandera,
                          style: const TextStyle(fontSize: 14)),
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
    final montoSrc =
        _parse(_editingTop ? _ctrlDesde.text : _ctrlHacia.text);
    final monedaSrc = _editingTop ? _desde : _hacia;
    final otras =
        _monedas.where((m) => m.code != _desde && m.code != _hacia).toList();

    return FadeTransition(
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
                  (_rates != null && montoSrc != null && montoSrc > 0)
                      ? _conv(montoSrc, monedaSrc, m.code, _rates!)
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
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // ZONA 3 — Tasas del día
  // ────────────────────────────────────────────────────────────────────────────
  Widget _zona3() {
    final filas = [
      (_m('USD'), _rates?.bcv, 'USD'),
      (_m('USDT'), _rates?.usdt, 'USDT'),
      (_m('EUR'), _rates?.eur, 'EUR'),
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
              final (moneda, tasa, code) = e.value;
              final esUltima = idx == filas.length - 1;
              final copiado = _copiado['tasa_$code'] == true;
              final tasaStr = tasa != null ? _fmt(tasa) : '—';
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
                        Text(moneda.nombre,
                            style: const TextStyle(
                                fontSize: 11, color: kTextSec)),
                        const Spacer(),
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
    final status = _dotStatus();
    Color tsColor = kTextDim;
    if (_isOffline) tsColor = kRed;
    if (!_isOffline && status == DataStatus.old) tsColor = kYellow;
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
          StatusDot(status: status, isLoading: _isLoading),
        ],
      ),
    );
  }
}
