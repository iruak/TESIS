import 'dart:async';
import 'package:flutter/material.dart';
import '../services/db_service.dart';
import '../services/ble_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BleService _ble = BleService();
  String _ultimaSync = 'Nunca';
  late final StreamSubscription<String> _eventSub;

  @override
  void initState() {
    super.initState();
    debugPrint('[HomeScreen] initState ejecutado');
    // Escuchar eventos del ESP32 para actualizar última sync
    _eventSub = _ble.eventStream.listen((msg) {
      debugPrint('[HomeScreen] Evento recibido en stream: $msg');
      if (msg == 'SYNC_END') {
        final now = DateTime.now();
        final formatted =
            '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        if (mounted) {
          setState(() => _ultimaSync = formatted);
        }
      }
    });
  }

  @override
  void dispose() {
    debugPrint('[HomeScreen] dispose ejecutado');
    _eventSub.cancel();
    super.dispose();
  }

  // ──────────────────────────────────────────
  // WIDGETS DE ESTADO BLE
  // ──────────────────────────────────────────

  Widget _buildIconBle(BleConnectionState estado) {
    switch (estado) {
      case BleConnectionState.buscando:
        return const SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            color: Colors.amber,
            strokeWidth: 4,
          ),
        );
      case BleConnectionState.conectado:
        return const Icon(Icons.bluetooth_connected, size: 48, color: Colors.green);
      case BleConnectionState.desconectado:
        return const Icon(Icons.bluetooth_disabled, size: 48, color: Colors.grey);
    }
  }

  String _textoEstado(BleConnectionState estado) {
    switch (estado) {
      case BleConnectionState.buscando:
        return 'Buscando dispositivo...';
      case BleConnectionState.conectado:
        return 'Estado: Conectado';
      case BleConnectionState.desconectado:
        return 'Estado: Desconectado';
    }
  }

  Color _colorEstado(BleConnectionState estado) {
    switch (estado) {
      case BleConnectionState.buscando:
        return Colors.amber.shade800;
      case BleConnectionState.conectado:
        return Colors.green.shade700;
      case BleConnectionState.desconectado:
        return Colors.grey.shade700;
    }
  }

  Widget _buildBotonBle(BuildContext context, BleConnectionState estado) {
    switch (estado) {
      case BleConnectionState.desconectado:
        return FilledButton.icon(
          onPressed: () {
            debugPrint('[HomeScreen] Botón "Buscar dispositivo" presionado');
            _ble.buscarDispositivo();
          },
          icon: const Icon(Icons.search),
          label: const Text('Buscar dispositivo'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
      case BleConnectionState.buscando:
        return FilledButton.icon(
          onPressed: null,
          icon: const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          label: const Text('Buscando...'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.amber,
          ),
        );
      case BleConnectionState.conectado:
        return OutlinedButton.icon(
          onPressed: () {
            debugPrint('[HomeScreen] Botón "Desconectar" presionado');
            _ble.desconectar();
          },
          icon: const Icon(Icons.bluetooth_disabled, color: Colors.red),
          label: const Text('Desconectar', style: TextStyle(color: Colors.red)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.red),
          ),
        );
    }
  }

  // ──────────────────────────────────────────
  // NAVEGACIÓN CON GUARD PARA ORDEÑO
  // ──────────────────────────────────────────

  void _navegarConGuard(BuildContext context, String route) {
    if (route == '/ordeno' &&
        _ble.estadoConexion != BleConnectionState.conectado) {
      debugPrint('[HomeScreen] Intento de navegación a /ordeno bloqueado: dispositivo no conectado');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero debes conectar el dispositivo'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    debugPrint('[HomeScreen] Navegando a ruta: $route');
    Navigator.pushNamed(context, route);
  }

  // ──────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sistema de Ordeño'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.password),
            tooltip: 'Cambiar PIN',
            onPressed: () => _mostrarDialogoCambiarPin(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Tarjeta de Estado Bluetooth ──
            ListenableBuilder(
              listenable: _ble,
              builder: (context, _) {
                final estado = _ble.estadoConexion;
                debugPrint('[HomeScreen] ListenableBuilder reconstruyendo. Estado BLE actual: $estado');
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildIconBle(estado),
                        const SizedBox(height: 8),
                        Text(
                          _textoEstado(estado),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _colorEstado(estado),
                              ),
                        ),
                        // Detalles del sistema si está conectado
                        if (estado == BleConnectionState.conectado) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildChipStatus(
                                'Bomba ${_ble.systemStatus.bomba}',
                                _ble.systemStatus.bomba == 'ON'
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              _buildChipStatus(
                                '${_ble.systemStatus.vacio.toStringAsFixed(1)} kPa',
                                Colors.blueGrey,
                              ),
                              const SizedBox(width: 8),
                              _buildChipStatus(
                                '🔋 ${_ble.systemStatus.bateria}%',
                                _ble.systemStatus.bateria > 30
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        _buildBotonBle(context, estado),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // ── Tarjeta de Última Sincronización ──
            Card(
              elevation: 1,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                child: Row(
                  children: [
                    const Icon(Icons.sync, color: Colors.black54),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Última sync: $_ultimaSync',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Menú Principal ──
            Text(
              'Menú Principal',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 16),

            _buildNavigationCard(
              context,
              title: 'Ordeño en Tiempo Real',
              icon: Icons.water_drop,
              route: '/ordeno',
              color: Colors.blueAccent,
            ),
            const SizedBox(height: 12),
            _buildNavigationCard(
              context,
              title: 'Historial General',
              icon: Icons.calendar_month,
              route: '/historial',
              color: Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildNavigationCard(
              context,
              title: 'Gestión de Vacas',
              icon: Icons.add_circle,
              route: '/agregar_vaca',
              color: Colors.green,
            ),
            const SizedBox(height: 12),
            _buildNavigationCard(
              context,
              title: 'Control Remoto',
              icon: Icons.settings_remote,
              route: '/control_remoto',
              color: Colors.grey[700]!,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChipStatus(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildNavigationCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String route,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navegarConGuard(context, route),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarDialogoCambiarPin(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final actualController = TextEditingController();
    final nuevoController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        bool isLoading = false;
        String? errorMensaje;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Cambiar PIN'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (errorMensaje != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text(errorMensaje!,
                            style: const TextStyle(color: Colors.red)),
                      ),
                    TextFormField(
                      controller: actualController,
                      decoration:
                          const InputDecoration(labelText: 'PIN Actual'),
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      validator: (v) => v!.isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nuevoController,
                      decoration: const InputDecoration(
                          labelText: 'Nuevo PIN (4-6 dígitos)'),
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 6,
                      validator: (v) {
                        if (v == null || v.length < 4) return 'Mínimo 4 dígitos';
                        if (!RegExp(r'^[0-9]+$').hasMatch(v)) {
                          return 'Solo números';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setState(() {
                              isLoading = true;
                              errorMensaje = null;
                            });
                            final db = DBService();
                            final valido =
                                await db.validarPin(actualController.text);
                            if (valido) {
                              await db.guardarPin(nuevoController.text);
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('PIN actualizado correctamente')),
                                );
                              }
                            } else {
                              setState(() {
                                isLoading = false;
                                errorMensaje = 'El PIN actual es incorrecto';
                              });
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
