import 'package:flutter/material.dart';
import '../services/db_service.dart';

class BienvenidaScreen extends StatefulWidget {
  const BienvenidaScreen({super.key});

  @override
  State<BienvenidaScreen> createState() => _BienvenidaScreenState();
}

class _BienvenidaScreenState extends State<BienvenidaScreen> {
  final DBService _dbService = DBService();
  bool _isLoading = true;
  bool _tienePin = false;
  bool _isProcessing = false;

  // Para crear PIN
  final _formKey = GlobalKey<FormState>();
  final _nuevoPinController = TextEditingController();
  final _confirmarPinController = TextEditingController();

  // Para ingresar PIN (teclado numérico custom)
  String _pinIngresado = "";
  final int _maxPinLength = 6; // PIN de 4 a 6 dígitos
  String? _errorMensaje;

  @override
  void initState() {
    super.initState();
    _verificarPinExistente();
  }

  Future<void> _verificarPinExistente() async {
    final existe = await _dbService.existePin();
    if (mounted) {
      setState(() {
        _tienePin = existe;
        _isLoading = false;
      });
    }
  }

  Future<void> _crearPin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isProcessing = true);
      await _dbService.guardarPin(_nuevoPinController.text);
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  void _onKeypadTap(String value) {
    if (_pinIngresado.length < _maxPinLength) {
      setState(() {
        _pinIngresado += value;
        _errorMensaje = null;
      });
      // Try to validate automatically if length is between 4 and 6?
      // Since PIN can be 4-6 digits, we might need a submit button or just auto-submit on 4/5/6.
      // Better to auto-submit when it reaches 4 digits if the saved PIN was 4 digits, but we only have hash.
      // Wait, we can't know the exact length from the hash. 
      // We will add an "OK" button to the keypad.
    }
  }

  void _onKeypadDelete() {
    if (_pinIngresado.isNotEmpty) {
      setState(() {
        _pinIngresado = _pinIngresado.substring(0, _pinIngresado.length - 1);
        _errorMensaje = null;
      });
    }
  }

  Future<void> _validarPinIngresado() async {
    if (_pinIngresado.isEmpty) return;
    
    setState(() => _isProcessing = true);
    final esValido = await _dbService.validarPin(_pinIngresado);
    
    if (mounted) {
      if (esValido) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        setState(() {
          _isProcessing = false;
          _errorMensaje = "PIN incorrecto";
          _pinIngresado = "";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: _tienePin ? _buildIngresarPin() : _buildCrearPin(),
          ),
        ),
      ),
    );
  }

  Widget _buildCrearPin() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.water_drop, size: 80, color: Theme.of(context).colorScheme.primary),
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
            controller: _nuevoPinController,
            decoration: const InputDecoration(
              labelText: 'Crear PIN (4 a 6 dígitos)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock),
            ),
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Ingresa un PIN';
              if (value.length < 4) return 'El PIN debe tener al menos 4 dígitos';
              if (!RegExp(r'^[0-9]+$').hasMatch(value)) return 'Solo números permitidos';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmarPinController,
            decoration: const InputDecoration(
              labelText: 'Confirmar PIN',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock_outline),
            ),
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            validator: (value) {
              if (value != _nuevoPinController.text) {
                return 'Los PINs no coinciden';
              }
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isProcessing
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Crear PIN y continuar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngresarPin() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock, size: 64, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 24),
        Text(
          'Ingresa tu PIN',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 32),
        // Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _maxPinLength,
            (index) {
              bool isFilled = index < _pinIngresado.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled ? Theme.of(context).colorScheme.primary : Colors.grey[300],
                ),
              );
            },
          ),
        ),
        if (_errorMensaje != null)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Text(
              _errorMensaje!,
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        const SizedBox(height: 48),
        // Numpad
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
              _buildNumpadButton('Borrar', icon: Icons.backspace_outlined, onTap: _onKeypadDelete),
              _buildNumpadButton('0'),
              _buildNumpadButton('OK', icon: Icons.check, onTap: _validarPinIngresado, isPrimary: true),
            ],
          ),
        ),
        if (_isProcessing)
          const Padding(
            padding: EdgeInsets.only(top: 24.0),
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }

  Widget _buildNumpadButton(String text, {IconData? icon, VoidCallback? onTap, bool isPrimary = false}) {
    final color = isPrimary ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest;
    final textColor = isPrimary ? Colors.white : Colors.black87;

    return InkWell(
      onTap: _isProcessing ? null : (onTap ?? () => _onKeypadTap(text)),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, color: textColor, size: 28)
              : Text(
                  text,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
                ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nuevoPinController.dispose();
    _confirmarPinController.dispose();
    super.dispose();
  }
}
