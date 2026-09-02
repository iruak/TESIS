import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/ble_service.dart';
import '../services/db_service.dart';
import '../models/vaca.dart';
import '../models/registro_ordeno.dart';

// Estados de la pantalla
enum OrdenoFase { seleccionVaca, enCurso, completado }

class OrdenoScreen extends StatefulWidget {
  const OrdenoScreen({super.key});

  @override
  State<OrdenoScreen> createState() => _OrdenoScreenState();
}

class _OrdenoScreenState extends State<OrdenoScreen> {
  final BleService _ble = BleService();
  final DBService _db = DBService();

  OrdenoFase _fase = OrdenoFase.seleccionVaca;
  List<Vaca> _vacas = [];
  Vaca? _vacaSeleccionada;
  bool _loadingVacas = true;

  // Resultado final del ordeño
  double _litrosFinales = 0;
  String _fechaFinal = '';
  String _horaFinal = '';

  late StreamSubscription<String> _eventSub;

  @override
  void initState() {
    super.initState();
    _cargarVacas();
    _escucharEventos();
  }

  Future<void> _cargarVacas() async {
    debugPrint('[OrdeñoScreen] Cargando lista de vacas...');
    final vacas = await _db.obtenerVacas();
    if (!mounted) return;

    setState(() {
      _vacas = vacas;
      _loadingVacas = false;

      // Si ya hay un ordeño en curso en BleService, reconectar la vaca seleccionada
      if (_ble.estaOrdenando && _ble.vacaIdEnOrdeno != null) {
        final vacaEnCurso = vacas.cast<Vaca?>().firstWhere(
              (v) => v?.id == _ble.vacaIdEnOrdeno,
              orElse: () => null,
            );
        if (vacaEnCurso != null) {
          debugPrint('[OrdeñoScreen] Reanudando visualización de vaca en curso: ${vacaEnCurso.nombre}');
          _vacaSeleccionada = vacaEnCurso;
          _fase = OrdenoFase.enCurso;
        }
      }
    });
  }

  void _escucharEventos() {
    _eventSub = _ble.eventStream.listen((msg) async {
      debugPrint('[OrdeñoScreen] Evento BLE recibido: $msg');
      final partes = msg.split('|');
      if (partes[0] == 'DONE' && partes.length >= 5) {
        final litros = double.tryParse(partes[2]) ?? 0.0;
        final fecha = partes[3];
        final hora = partes[4];

        if (_vacaSeleccionada != null && mounted) {
          debugPrint('[OrdeñoScreen] Procesando DONE automático para ${_vacaSeleccionada!.nombre}');
          // Guardar en base de datos
          final registro = RegistroOrdeno(
            vacaId: _vacaSeleccionada!.id!,
            fecha: fecha,
            hora: hora,
            litros: litros,
            sincronizado: 1, // viene directo del dispositivo
          );
          await _db.insertarRegistro(registro);
          debugPrint('[OrdeñoScreen] Registro guardado tras DONE');

          if (mounted) {
            setState(() {
              _litrosFinales = litros;
              _fechaFinal = fecha;
              _horaFinal = hora;
              _fase = OrdenoFase.completado;
            });
          }
        }
      }
    });
  }

  void _seleccionarVaca(Vaca vaca) {
    debugPrint('[OrdeñoScreen] Vaca seleccionada para ordeñar: ${vaca.nombre} (#${vaca.numero})');
    setState(() {
      _vacaSeleccionada = vaca;
      _fase = OrdenoFase.enCurso;
    });
    // Iniciar ordeño en el servicio BLE
    _ble.iniciarOrdeno(vaca.id!);
  }

  Future<void> _detenerManualmente() async {
    debugPrint('[OrdeñoScreen] _detenerManualmente presionado');
    if (_vacaSeleccionada == null) {
      debugPrint('[OrdeñoScreen] _vacaSeleccionada es null');
      return;
    }

    final litrosActuales = _ble.ordenoStatus.litros;
    debugPrint('[OrdeñoScreen] Litros al presionar detener: $litrosActuales. Mostrando confirmación...');

    final bool? confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.stop_circle_outlined, size: 48, color: Colors.red),
        title: const Text(
          'Detener Ordeño',
          style: TextStyle(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Text(
          '¿Detener el ordeño de ${_vacaSeleccionada!.nombre}?\nSe guardará con ${litrosActuales.toStringAsFixed(2)} litros registrados hasta el momento.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          OutlinedButton(
            onPressed: () {
              debugPrint('[OrdeñoScreen] Usuario canceló detención');
              Navigator.pop(ctx, false);
            },
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              debugPrint('[OrdeñoScreen] Usuario confirmó detención');
              Navigator.pop(ctx, true);
            },
            child: const Text('Detener y Guardar'),
          ),
        ],
      ),
    );

    debugPrint('[OrdeñoScreen] Resultado confirmación: $confirmar (mounted: $mounted)');
    if (confirmar != true) return;
    if (!mounted) return;

    final now = DateTime.now();
    final fecha = DateFormat('yyyy-MM-dd').format(now);
    final hora = DateFormat('HH:mm').format(now);
    final litros = _ble.ordenoStatus.litros;

    debugPrint('[OrdeñoScreen] Ejecutando _ble.pararEmergencia()...');
    // Parar el timer y resetear estado en BleService
    await _ble.pararEmergencia();

    debugPrint('[OrdeñoScreen] Guardando registro parcial ($litros L) en SQLite...');
    // Guardar el registro parcial en la base de datos
    final registro = RegistroOrdeno(
      vacaId: _vacaSeleccionada!.id!,
      fecha: fecha,
      hora: hora,
      litros: litros,
      sincronizado: 1,
    );
    await _db.insertarRegistro(registro);
    debugPrint('[OrdeñoScreen] Registro guardado exitosamente. Pasando a fase completado.');

    if (!mounted) return;
    setState(() {
      _litrosFinales = litros;
      _fechaFinal = fecha;
      _horaFinal = hora;
      _fase = OrdenoFase.completado;
    });
  }

  void _ordenarSiguiente() {
    debugPrint('[OrdeñoScreen] Volviendo a selección de vaca');
    if (!mounted) return;
    setState(() {
      _fase = OrdenoFase.seleccionVaca;
      _vacaSeleccionada = null;
      _litrosFinales = 0;
    });
  }

  @override
  void dispose() {
    debugPrint('[OrdeñoScreen] dispose ejecutado');
    _eventSub.cancel();
    super.dispose();
  }

  // ══════════════════════════════════════════
  // BUILD PRINCIPAL
  // ══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    switch (_fase) {
      case OrdenoFase.seleccionVaca:
        return _buildSeleccionVaca();
      case OrdenoFase.enCurso:
        return _buildOrdenoEnCurso();
      case OrdenoFase.completado:
        return _buildCompletado();
    }
  }

  // ══════════════════════════════════════════
  // FASE 1 — SELECCIÓN DE VACA
  // ══════════════════════════════════════════

  Widget _buildSeleccionVaca() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ordeño — Seleccionar Vaca'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: _loadingVacas
          ? const Center(child: CircularProgressIndicator())
          : _vacas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning_amber,
                          size: 64, color: Colors.orange.shade400),
                      const SizedBox(height: 16),
                      const Text(
                        'No hay vacas registradas.\nAgrega vacas primero desde el menú principal.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListenableBuilder(
                  listenable: _ble,
                  builder: (context, _) {
                    final hayOrdenoEnCurso = _ble.estaOrdenando;
                    final vacaEnCursoId = _ble.vacaIdEnOrdeno;

                    return Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          child: Row(
                            children: [
                              Icon(
                                hayOrdenoEnCurso
                                    ? Icons.sync_rounded
                                    : Icons.touch_app_rounded,
                                color: hayOrdenoEnCurso
                                    ? Colors.blueAccent
                                    : Colors.black54,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  hayOrdenoEnCurso
                                      ? 'Ordeño en curso activo (1 vaca a la vez)'
                                      : '¿A qué vaca vas a ordeñar?',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: hayOrdenoEnCurso
                                            ? Colors.blue.shade900
                                            : null,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _vacas.length,
                            itemBuilder: (ctx, i) {
                              final vaca = _vacas[i];
                              final esLaVacaEnCurso =
                                  hayOrdenoEnCurso && vaca.id == vacaEnCursoId;
                              final deshabilitada =
                                  hayOrdenoEnCurso && !esLaVacaEnCurso;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Card(
                                  elevation: esLaVacaEnCurso
                                      ? 4
                                      : (deshabilitada ? 0 : 3),
                                  color: esLaVacaEnCurso
                                      ? Colors.blue.shade50
                                      : (deshabilitada
                                          ? Colors.grey.shade100
                                          : null),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color: esLaVacaEnCurso
                                          ? Colors.blueAccent
                                          : (deshabilitada
                                              ? Colors.grey.shade300
                                              : Colors.transparent),
                                      width: esLaVacaEnCurso ? 2 : 1,
                                    ),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: deshabilitada
                                        ? null
                                        : () {
                                            if (esLaVacaEnCurso) {
                                              setState(() {
                                                _vacaSeleccionada = vaca;
                                                _fase = OrdenoFase.enCurso;
                                              });
                                            } else {
                                              _seleccionarVaca(vaca);
                                            }
                                          },
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 28,
                                            backgroundColor: esLaVacaEnCurso
                                                ? Colors.blueAccent
                                                : (deshabilitada
                                                    ? Colors.grey.shade300
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .primaryContainer),
                                            child: Text(
                                              vaca.numero,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                                color: esLaVacaEnCurso
                                                    ? Colors.white
                                                    : (deshabilitada
                                                        ? Colors.grey.shade600
                                                        : Theme.of(context)
                                                            .colorScheme
                                                            .primary),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        vaca.nombre,
                                                        style: TextStyle(
                                                          fontSize: 20,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: deshabilitada
                                                              ? Colors.grey.shade600
                                                              : Colors.black87,
                                                        ),
                                                      ),
                                                    ),
                                                    if (esLaVacaEnCurso)
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 10,
                                                                vertical: 4),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .blueAccent,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                        ),
                                                        child: const Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            SizedBox(
                                                              width: 12,
                                                              height: 12,
                                                              child:
                                                                  CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                            ),
                                                            SizedBox(width: 6),
                                                            Text(
                                                              'Ordeñando...',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      )
                                                    else if (deshabilitada)
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 8,
                                                                vertical: 3),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .grey.shade200,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                        ),
                                                        child: Text(
                                                          'En espera',
                                                          style: TextStyle(
                                                            color: Colors.grey
                                                                .shade600,
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  vaca.raza,
                                                  style: TextStyle(
                                                    color: deshabilitada
                                                        ? Colors.grey.shade400
                                                        : Colors.grey[600],
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            esLaVacaEnCurso
                                                ? Icons.play_circle_filled_rounded
                                                : (deshabilitada
                                                    ? Icons.lock_outline_rounded
                                                    : Icons.arrow_forward_ios),
                                            color: esLaVacaEnCurso
                                                ? Colors.blueAccent
                                                : (deshabilitada
                                                    ? Colors.grey.shade400
                                                    : Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }

  // ══════════════════════════════════════════
  // FASE 2 — ORDEÑO EN CURSO
  // ══════════════════════════════════════════

  Widget _buildOrdenoEnCurso() {
    final now = DateTime.now();
    final fechaHora = DateFormat('dd/MM/yyyy  HH:mm').format(now);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ordeñando: ${_vacaSeleccionada?.nombre ?? ""} (${_vacaSeleccionada?.numero ?? ""})',
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        automaticallyImplyLeading: false,
      ),
      body: ListenableBuilder(
        listenable: _ble,
        builder: (context, _) {
          final litros = _ble.ordenoStatus.litros;
          final tiempo = _ble.ordenoStatus.tiempo;

          return Column(
            children: [
              // Fecha y hora
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Center(
                  child: Text(
                    fechaHora,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ),

              // Indicador central de litros
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.15),
                            Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.05),
                          ],
                        ),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 4,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.water_drop,
                            color: Colors.blueAccent,
                            size: 40,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            litros.toStringAsFixed(2),
                            style: TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.w900,
                              color: Theme.of(context).colorScheme.primary,
                              height: 1.0,
                            ),
                          ),
                          Text(
                            'litros',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Tiempo transcurrido
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.timer,
                            color: Colors.black45, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          tiempo,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            fontFeatures: [FontFeature.tabularFigures()],
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 48),

                    // Botón detener manualmente
                    OutlinedButton.icon(
                      onPressed: _detenerManualmente,
                      icon: const Icon(Icons.stop_circle_outlined,
                          color: Colors.red),
                      label: const Text(
                        'Detener manualmente',
                        style: TextStyle(color: Colors.red, fontSize: 16),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        side: const BorderSide(color: Colors.red, width: 2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════
  // FASE 3 — COMPLETADO
  // ══════════════════════════════════════════

  Widget _buildCompletado() {
    String fechaFormateada = _fechaFinal;
    try {
      final parsed = DateFormat('yyyy-MM-dd').parse(_fechaFinal);
      fechaFormateada = DateFormat('dd/MM/yyyy').format(parsed);
    } catch (_) {}

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ordeño Completado'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ícono de check
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 68,
                ),
              ),

              const SizedBox(height: 20),

              Text(
                '¡Vaca ${_vacaSeleccionada?.nombre ?? ""} completada!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
              ),

              const SizedBox(height: 24),

              // Tarjeta de resumen
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      _buildResumenFila(
                        Icons.water_drop,
                        'Litros producidos',
                        '${_litrosFinales.toStringAsFixed(2)} L',
                        Colors.blueAccent,
                        grande: true,
                      ),
                      const Divider(height: 24),
                      _buildResumenFila(
                        Icons.calendar_today,
                        'Fecha',
                        fechaFormateada,
                        Colors.black54,
                      ),
                      const SizedBox(height: 8),
                      _buildResumenFila(
                        Icons.access_time,
                        'Hora',
                        _horaFinal,
                        Colors.black54,
                      ),
                      const SizedBox(height: 8),
                      _buildResumenFila(
                        Icons.save_alt,
                        'Estado',
                        'Guardado ✓',
                        Colors.green,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Botones de acción
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _ordenarSiguiente,
                  icon: const Icon(Icons.skip_next),
                  label: const Text('Ordeñar siguiente vaca',
                      style: TextStyle(fontSize: 16)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context, '/home', (r) => false),
                  icon: const Icon(Icons.home),
                  label: const Text('Volver al inicio',
                      style: TextStyle(fontSize: 16)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResumenFila(
      IconData icon, String label, String valor, Color color,
      {bool grande = false}) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        ),
        Text(
          valor,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: grande ? 22 : 16,
          ),
        ),
      ],
    );
  }
}
