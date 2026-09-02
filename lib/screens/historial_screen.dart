import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/db_service.dart';
import '../models/vaca.dart';
import '../models/registro_ordeno.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  final DBService _dbService = DBService();
  late Future<_HistorialData> _historialDataFuture;
  DateTime _selectedDate = DateTime.now();
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _historialDataFuture = _cargarDatos();
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

  Future<void> _exportarCsv(_HistorialData data) async {
    if (data.vacas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para exportar en esta fecha')),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      final List<List<dynamic>> rows = [];
      rows.add(['Fecha', 'Vaca', 'Número', 'Litros', 'Estado']);

      final fechaExport = DateFormat('yyyy-MM-dd').format(_selectedDate);

      for (final vaca in data.vacas) {
        final regIndex = data.registros.indexWhere((r) => r.vacaId == vaca.id);
        final tieneRegistro = regIndex != -1;
        final litros = tieneRegistro ? data.registros[regIndex].litros.toString() : '--';
        final estado = tieneRegistro ? 'Visto' : 'Falta';
        rows.add([fechaExport, vaca.nombre, vaca.numero, litros, estado]);
      }
      
      // Agregar fila de total
      rows.add([]);
      rows.add(['Total del día', '', '', data.totalLitros.toString(), '']);

      final String csvData = ListToCsvConverter().convert(rows);
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/resumen_diario_$fechaExport.csv';
      final file = File(path);
      await file.writeAsString(csvData);

      await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: 'Resumen Diario de Ordeño - $fechaExport'));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e')),
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
                            onPressed: _isExporting ? null : () => _exportarCsv(data),
                            icon: _isExporting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.file_download),
                            label: Text(_isExporting ? 'Exportando...' : 'Exportar CSV'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Theme.of(context).colorScheme.secondary,
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
