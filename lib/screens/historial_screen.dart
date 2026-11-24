import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../services/db_service.dart';
import '../services/sync_service.dart';
import '../services/reporte_excel_service.dart';
import '../models/vaca.dart';
import '../models/registro_ordeno.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  final DBService _dbService = DBService();
  final SyncService _sync = SyncService();
  late Future<_HistorialData> _historialDataFuture;
  DateTime _selectedDate = DateTime.now();
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _historialDataFuture = _cargarDatos();
    _sync.addListener(_onSync);
  }

  void _onSync() {
    // Recarga los datos cuando llega una sincronización completada
    if (!_sync.sincronizando && mounted) {
      setState(() {
        _historialDataFuture = _cargarDatos();
      });
    }
  }

  @override
  void dispose() {
    _sync.removeListener(_onSync);
    super.dispose();
  }

  Future<_HistorialData> _cargarDatos() async {
    final fechaDB = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final fechaMostrar = DateFormat('dd/MM/yyyy').format(_selectedDate);

    final vacas = await _dbService.obtenerVacas();
    final registros = await _dbService.obtenerRegistrosPorFecha(fechaDB);
    final total = await _dbService.obtenerTotalLitrosPorFecha(fechaDB);

    final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == fechaDB;
    String horaInicio = isToday ? "Sin ordeños hoy" : "Sin ordeños este día";
    
    if (registros.isNotEmpty) {
      final registrosOrdenados = List<RegistroOrdeno>.from(registros);
      registrosOrdenados.sort((a, b) => a.hora.compareTo(b.hora));
      horaInicio = "Inicio: ${registrosOrdenados.first.hora}";
    }

    return _HistorialData(
      fechaMostrar: fechaMostrar,
      horaInicio: horaInicio,
      vacas: vacas,
      registros: registros,
      totalLitros: total,
      isToday: isToday,
    );
  }

  void _cambiarFecha(DateTime newDate) {
    setState(() {
      _selectedDate = newDate;
      _historialDataFuture = _cargarDatos();
    });
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      _cambiarFecha(picked);
    }
  }

  Future<DateTime?> _mostrarSelectorMes(
      BuildContext context, DateTime fechaInicial) async {
    int anoSeleccionado = fechaInicial.year;
    int mesSeleccionado = fechaInicial.month;

    const mesesNombres = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];

    return await showDialog<DateTime>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.calendar_month_rounded,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  const Text('Reporte Mensual',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Selecciona el mes y año para exportar el reporte general completo en Excel (.xlsx):',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    const SizedBox(height: 16),
                    // Selector de año
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_rounded,
                                size: 18),
                            onPressed: () {
                              setModalState(() => anoSeleccionado--);
                            },
                          ),
                          Text(
                            '$anoSeleccionado',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios_rounded,
                                size: 18),
                            onPressed: () {
                              setModalState(() => anoSeleccionado++);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Grilla de meses
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(12, (index) {
                        final m = index + 1;
                        final esSeleccionado = m == mesSeleccionado;
                        return SizedBox(
                          width: 68,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              setModalState(() => mesSeleccionado = m);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: esSeleccionado
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: esSeleccionado
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  mesesNombres[index].substring(0, 3),
                                  style: TextStyle(
                                    fontWeight: esSeleccionado
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: esSeleccionado
                                        ? Colors.white
                                        : Colors.black87,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(
                      ctx, DateTime(anoSeleccionado, mesSeleccionado, 1)),
                  icon: const Icon(Icons.file_download_rounded, size: 18),
                  label: const Text('Generar Excel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportarReporteMensual() async {
    final mesElegido = await _mostrarSelectorMes(context, _selectedDate);
    if (mesElegido == null || !mounted) return;

    setState(() => _isExporting = true);

    try {
      final fechaInicio = DateFormat('yyyy-MM-01').format(mesElegido);
      final ultimoDiaMes = DateTime(mesElegido.year, mesElegido.month + 1, 0);
      final fechaFin = DateFormat('yyyy-MM-dd').format(ultimoDiaMes);

      final registrosMes =
          await _dbService.obtenerRegistrosPorRango(fechaInicio, fechaFin);

      if (registrosMes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay ordeños registrados en este mes'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final vacas = await _dbService.obtenerVacas();

      final path = await ReporteExcelService.generarReporteGeneralMensual(
        mes: mesElegido,
        vacas: vacas,
        registros: registrosMes,
      );

      final nombreMes =
          ReporteExcelService.nombreMesEspanol(mesElegido.month);

      await SharePlus.instance.share(ShareParams(
        files: [
          XFile(
            path,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          )
        ],
        text: 'Reporte General de Ordeño - $nombreMes ${mesElegido.year}',
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar reporte: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial - Resumen'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: FutureBuilder<_HistorialData>(
        future: _historialDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('Sin datos'));
          }

          final data = snapshot.data!;

          return Column(
            children: [
              // Encabezado
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.today, size: 20, color: Colors.black54),
                        const SizedBox(width: 8),
                        Text(
                          data.fechaMostrar,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        if (!data.isToday)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: InkWell(
                              onTap: () => _cambiarFecha(DateTime.now()),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Volver a Hoy',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      data.horaInicio,
                      style: TextStyle(
                        color: data.registros.isEmpty
                            ? Colors.grey[700]
                            : Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Lista de Vacas
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: data.vacas.length,
                  itemBuilder: (context, index) {
                    final vaca = data.vacas[index];
                    final match = data.registros.where((r) => r.vacaId == vaca.id);
                    final registro = match.isNotEmpty ? match.first : null;
                    final bool tieneRegistro = registro != null;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.1),
                              child: Text(
                                vaca.numero,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              'Vaca ${vaca.numero} - ${vaca.nombre}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  tieneRegistro ? '${registro.litros} L' : '-- L',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: tieneRegistro
                                        ? Colors.black87
                                        : Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                if (tieneRegistro)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.check_circle,
                                            color: Colors.green, size: 16),
                                        SizedBox(width: 4),
                                        Text('Visto',
                                            style: TextStyle(
                                                color: Colors.green,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.warning,
                                            color: Colors.orange.shade800,
                                            size: 16),
                                        const SizedBox(width: 4),
                                        Text('Falta',
                                            style: TextStyle(
                                                color: Colors.orange.shade800,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Botón para ver historial de la vaca
                          Divider(height: 1, color: Colors.grey[300]),
                          InkWell(
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/historial_vaca',
                                arguments: vaca,
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.history, size: 18, color: Theme.of(context).colorScheme.secondary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Ver historial de vaca',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.secondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Sección Total y Botón
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      color: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total día:',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${data.totalLitros} L',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _seleccionarFecha(context),
                            icon: const Icon(Icons.date_range),
                            label: const Text('Fecha'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(
                                  color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _isExporting ? null : _exportarReporteMensual,
                            icon: _isExporting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.table_view_rounded),
                            label: Text(
                                _isExporting ? 'Exportando...' : 'Exportar Excel'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor:
                                  Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                        ),
                      ],
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
}

class _HistorialData {
  final String fechaMostrar;
  final String horaInicio;
  final List<Vaca> vacas;
  final List<RegistroOrdeno> registros;
  final double totalLitros;
  final bool isToday;

  _HistorialData({
    required this.fechaMostrar,
    required this.horaInicio,
    required this.vacas,
    required this.registros,
    required this.totalLitros,
    required this.isToday,
  });
}
