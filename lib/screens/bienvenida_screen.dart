import 'package:flutter/material.dart';
import '../services/db_service.dart';

// ─────────────────────────────────────────────────────────────────
// Preguntas de seguridad predefinidas
// ─────────────────────────────────────────────────────────────────
const _preguntasSeguridad = [
  '¿Cuál fue el nombre de tu primera mascota?',
  '¿En qué año nació tu hermano/a mayor?',
  '¿Cuál fue el primer lugar que visitaste de niño?',
  '¿Cuál es el nombre de tu pueblo natal?',
  '¿Cuál fue tu primer trabajo?',
];

class BienvenidaScreen extends StatefulWidget {
  const BienvenidaScreen({super.key});

  @override
  State<BienvenidaScreen> createState() => _BienvenidaScreenState();
}

// ─────────────────────────────────────────────────────────────────
// Fases del flujo de BienvenidaScreen
// ─────────────────────────────────────────────────────────────────
enum _Fase { cargando, crearPin, preguntaSeguridad, ingresarPin }

class _BienvenidaScreenState extends State<BienvenidaScreen> {
  final DBService _db = DBService();

  _Fase _fase = _Fase.cargando;
  bool _isProcessing = false;

  // ── Crear PIN ──────────────────────────────────────────────────
  final _formKeyPin = GlobalKey<FormState>();
  final _nuevoPinCtrl = TextEditingController();
  final _confirmarPinCtrl = TextEditingController();

  // ── Pregunta de seguridad ──────────────────────────────────────
  final _formKeySeguridad = GlobalKey<FormState>();
  String _preguntaSeleccionada = _preguntasSeguridad.first;
  final _respuestaCtrl = TextEditingController();

  // ── Ingresar PIN ───────────────────────────────────────────────
  String _pinIngresado = '';
  final int _maxPinLength = 6;
  String? _errorMensaje;

  @override
  void initState() {
    super.initState();
    _verificarEstado();
  }

  @override
  void dispose() {
    _nuevoPinCtrl.dispose();
    _confirmarPinCtrl.dispose();
    _respuestaCtrl.dispose();
    super.dispose();
  }

  Future<void> _verificarEstado() async {
    final existe = await _db.existePin();
    if (mounted) {
      setState(() {
        _fase = existe ? _Fase.ingresarPin : _Fase.crearPin;
      });
    }
  }

  // ─── Flujo "Crear PIN" ────────────────────────────────────────

  Future<void> _crearPin() async {
    if (!_formKeyPin.currentState!.validate()) return;
    setState(() => _isProcessing = true);
    await _db.guardarPin(_nuevoPinCtrl.text);
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _fase = _Fase.preguntaSeguridad;
      });
    }
  }

  // ─── Flujo "Pregunta de Seguridad" ───────────────────────────

  Future<void> _guardarPreguntaYContinuar() async {
    if (!_formKeySeguridad.currentState!.validate()) return;
    setState(() => _isProcessing = true);
    await _db.guardarPreguntaSeguridad(
        _preguntaSeleccionada, _respuestaCtrl.text);
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  // ─── Flujo "Ingresar PIN" ─────────────────────────────────────

  void _onKeypadTap(String value) {
    if (_pinIngresado.length < _maxPinLength) {
      setState(() {
        _pinIngresado += value;
        _errorMensaje = null;
      });
    }
  }

  void _onKeypadDelete() {
    if (_pinIngresado.isNotEmpty) {
      setState(() {
        _pinIngresado =
            _pinIngresado.substring(0, _pinIngresado.length - 1);
        _errorMensaje = null;
      });
    }
  }

  Future<void> _validarPin() async {
    if (_pinIngresado.isEmpty) return;
    setState(() => _isProcessing = true);
    final esValido = await _db.validarPin(_pinIngresado);
    if (mounted) {
      if (esValido) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        setState(() {
          _isProcessing = false;
          _errorMensaje = 'PIN incorrecto. Intenta de nuevo.';
          _pinIngresado = '';
        });
      }
    }
  }

  void _abrirRecuperacionPin() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecuperarPinSheet(db: _db),
    ).then((pinCambiado) {
      if (pinCambiado == true && mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    });
  }

  // ─── BUILD ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: switch (_fase) {
              _Fase.cargando => const CircularProgressIndicator(),
              _Fase.crearPin => _buildCrearPin(),
              _Fase.preguntaSeguridad => _buildPreguntaSeguridad(),
              _Fase.ingresarPin => _buildIngresarPin(),
            },
          ),
        ),
      ),
    );
  }

  // ─── Widget: Crear PIN ────────────────────────────────────────

  Widget _buildCrearPin() {
    return Form(
      key: _formKeyPin,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.water_drop,
              size: 80, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            'Sistema de Ordeño Inteligente',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Protege el acceso configurando un PIN seguro.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
          const SizedBox(height: 48),
          TextFormField(
            controller: _nuevoPinCtrl,
            decoration: const InputDecoration(
              labelText: 'Crear PIN (4 a 6 dígitos)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock),
            ),
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Ingresa un PIN';
              if (v.length < 4) return 'El PIN debe tener al menos 4 dígitos';
              if (!RegExp(r'^[0-9]+$').hasMatch(v)) {
                return 'Solo números permitidos';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmarPinCtrl,
            decoration: const InputDecoration(
              labelText: 'Confirmar PIN',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock_outline),
            ),
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            validator: (v) {
              if (v != _nuevoPinCtrl.text) return 'Los PINs no coinciden';
              return null;
            },
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isProcessing ? null : _crearPin,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Crear PIN y continuar',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Widget: Pregunta de Seguridad ───────────────────────────

  Widget _buildPreguntaSeguridad() {
    return Form(
      key: _formKeySeguridad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Icon(Icons.security,
                size: 64, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Pregunta de Seguridad',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Esto te permitirá recuperar el acceso si olvidas tu PIN.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 32),
          Text('Selecciona una pregunta:',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _preguntaSeleccionada,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            isExpanded: true,
            items: _preguntasSeguridad
                .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14)),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _preguntaSeleccionada = v);
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _respuestaCtrl,
            decoration: const InputDecoration(
              labelText: 'Tu respuesta',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.edit_note),
              helperText: 'No distingue mayúsculas ni espacios iniciales/finales',
            ),
            textCapitalization: TextCapitalization.none,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Escribe tu respuesta';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isProcessing ? null : _guardarPreguntaYContinuar,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Guardar y entrar',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Widget: Ingresar PIN ─────────────────────────────────────

  Widget _buildIngresarPin() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock,
            size: 64, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 24),
        Text(
          'Ingresa tu PIN',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 32),
        // Puntos del PIN
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_maxPinLength, (i) {
            final filled = i < _pinIngresado.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[300],
              ),
            );
          }),
        ),
        if (_errorMensaje != null)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Text(
              _errorMensaje!,
              style:
                  const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        const SizedBox(height: 48),
        // Teclado numérico
        SizedBox(
          width: 280,
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 1; i <= 9; i++) _buildNumpadButton('$i'),
              _buildNumpadButton('Borrar',
                  icon: Icons.backspace_outlined,
                  onTap: _onKeypadDelete),
              _buildNumpadButton('0'),
              _buildNumpadButton('OK',
                  icon: Icons.check,
                  onTap: _validarPin,
                  isPrimary: true),
            ],
          ),
        ),
        if (_isProcessing)
          const Padding(
            padding: EdgeInsets.only(top: 24.0),
            child: CircularProgressIndicator(),
          ),
        const SizedBox(height: 24),
        // Link "¿Olvidaste tu PIN?"
        TextButton.icon(
          onPressed: _abrirRecuperacionPin,
          icon: const Icon(Icons.help_outline, size: 18),
          label: const Text('¿Olvidaste tu PIN?'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildNumpadButton(String text,
      {IconData? icon, VoidCallback? onTap, bool isPrimary = false}) {
    final color = isPrimary
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final textColor = isPrimary ? Colors.white : Colors.black87;

    return InkWell(
      onTap: _isProcessing ? null : (onTap ?? () => _onKeypadTap(text)),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: Center(
          child: icon != null
              ? Icon(icon, color: textColor, size: 28)
              : Text(text,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textColor)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Bottom Sheet: Recuperar PIN con pregunta de seguridad
// ─────────────────────────────────────────────────────────────────
class _RecuperarPinSheet extends StatefulWidget {
  final DBService db;
  const _RecuperarPinSheet({required this.db});

  @override
  State<_RecuperarPinSheet> createState() => _RecuperarPinSheetState();
}

class _RecuperarPinSheetState extends State<_RecuperarPinSheet> {
  final _formKey = GlobalKey<FormState>();
  final _respuestaCtrl = TextEditingController();
  final _nuevoPinCtrl = TextEditingController();
  final _confirmarPinCtrl = TextEditingController();

  String? _pregunta;
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _respuestaCorrecta = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarPregunta();
  }

  @override
  void dispose() {
    _respuestaCtrl.dispose();
    _nuevoPinCtrl.dispose();
    _confirmarPinCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarPregunta() async {
    final p = await widget.db.obtenerPreguntaSeguridad();
    if (mounted) {
      setState(() {
        _pregunta = p;
        _isLoading = false;
      });
    }
  }

  Future<void> _validarRespuesta() async {
    if (_respuestaCtrl.text.trim().isEmpty) return;
    setState(() {
      _isProcessing = true;
      _error = null;
    });
    final ok = await widget.db.validarRespuestaSeguridad(_respuestaCtrl.text);
    if (mounted) {
      if (ok) {
        setState(() {
          _respuestaCorrecta = true;
          _isProcessing = false;
        });
      } else {
        setState(() {
          _error = 'Respuesta incorrecta. Intenta de nuevo.';
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _guardarNuevoPin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isProcessing = true);
    await widget.db.guardarPin(_nuevoPinCtrl.text);
    if (mounted) {
      Navigator.pop(context, true); // true = PIN cambiado → ir a Home
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Asa
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Recuperar acceso',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 20),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_pregunta == null)
              _buildSinPregunta()
            else if (!_respuestaCorrecta)
              _buildFormRespuesta()
            else
              _buildFormNuevoPin(),
          ],
        ),
      ),
    );
  }

  Widget _buildSinPregunta() {
    return Column(
      children: [
        const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
        const SizedBox(height: 12),
        const Text(
          'No hay pregunta de seguridad configurada.\n'
          'No es posible recuperar el PIN de esta forma.\n\n'
          'Contacta al administrador del sistema.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Widget _buildFormRespuesta() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _pregunta!,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _respuestaCtrl,
          decoration: InputDecoration(
            labelText: 'Tu respuesta',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.edit_note),
            errorText: _error,
          ),
          textCapitalization: TextCapitalization.none,
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _isProcessing ? null : _validarRespuesta,
          child: _isProcessing
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child:
                      CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Verificar respuesta'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }

  Widget _buildFormNuevoPin() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.check_circle, size: 48, color: Colors.green),
          const SizedBox(height: 8),
          const Text(
            'Respuesta correcta. Crea un nuevo PIN.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _nuevoPinCtrl,
            decoration: const InputDecoration(
              labelText: 'Nuevo PIN (4-6 dígitos)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock),
            ),
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            validator: (v) {
              if (v == null || v.length < 4) return 'Mínimo 4 dígitos';
              if (!RegExp(r'^[0-9]+$').hasMatch(v)) return 'Solo números';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmarPinCtrl,
            decoration: const InputDecoration(
              labelText: 'Confirmar PIN',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock_outline),
            ),
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            validator: (v) {
              if (v != _nuevoPinCtrl.text) return 'Los PINs no coinciden';
              return null;
            },
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isProcessing ? null : _guardarNuevoPin,
            child: _isProcessing
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Guardar nuevo PIN y entrar'),
          ),
        ],
      ),
    );
  }
}
