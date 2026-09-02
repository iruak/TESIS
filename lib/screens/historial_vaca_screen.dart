import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import '../services/db_service.dart';
import '../models/vaca.dart';
import '../models/registro_ordeno.dart';

enum FilterType { semana, mes, personalizado }

class HistorialVacaScreen extends StatefulWidget {
  const HistorialVacaScreen({super.key});

  @override
  State<HistorialVacaScreen> createState() => _HistorialVacaScreenState();
}

class _HistorialVacaScreenState extends State<HistorialVacaScreen> {
  final DBService _dbService = DBService();
  late Future<_HistorialVacaData> _dataFuture;
  Vaca? _vaca;
  bool _isInit = false;

  FilterType _currentFilter = FilterType.semana;
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = now.subtract(const Duration(days: 7));
    _endDate = now;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Vaca) {
        _vaca = args;
        _dataFuture = _cargarDatos(_vaca!.id!);
      }
      _isInit = true;
    }
  }

  Future<_HistorialVacaData> _cargarDatos(int vacaId) async {
    final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(_endDate);

    final registros = await _dbService.obtenerRegistrosPorVacaYRango(
        vacaId, startStr, endStr);
    
    // Ordenar de más reciente a más antiguo
    registros.sort((a, b) {
      final dateComparison = b.fecha.compareTo(a.fecha);
      if (dateComparison != 0) return dateComparison;
      return b.hora.compareTo(a.hora);
    });

    final promedio = await _dbService.obtenerPromedioLitrosPorVacaYRango(
        vacaId, startStr, endStr);
    final total = await _dbService.obtenerTotalLitrosPorVacaYRango(
        vacaId, startStr, endStr);

    return _HistorialVacaData(
      registros: registros,
      promedio: promedio,
      totalRango: total,
    );
  }

  void _aplicarFiltro(FilterType tipo) async {
    if (tipo == FilterType.personalizado) {
      final DateTimeRange? picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme,
            ),
            child: child!,
          );
        },
      );
      if (picked != null) {
        setState(() {
          _currentFilter = FilterType.personalizado;
          _startDate = picked.start;
          _endDate = picked.end;
          _dataFuture = _cargarDatos(_vaca!.id!);
        });
      }
    } else {
      setState(() {
        _currentFilter = tipo;
        final now = DateTime.now();
        if (tipo == FilterType.semana) {
          _startDate = now.subtract(const Duration(days: 7));
          _endDate = now;
        } else if (tipo == FilterType.mes) {
          _startDate = DateTime(now.year, now.month, 1);
          // last day of current month
          _endDate = DateTime(now.year, now.month + 1, 0); 
        }
        _dataFuture = _cargarDatos(_vaca!.id!);
      });
    }
  }

  Future<void> _exportarCsv(_HistorialVacaData data) async {
    if (data.registros.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para exportar en este rango')),
      );
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      final List<List<dynamic>> rows = [];
      // Header
      rows.add(['Fecha', 'Hora', 'Litros', 'Estado']);

      // Data
      for (final r in data.registros) {
        rows.add([r.fecha, r.hora, r.litros, 'Completado']);
      }

      final String csvData = ListToCsvConverter().convert(rows);

      final directory = await getTemporaryDirectory();
      
      final String startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final String endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);
      final String nombreVaca = _vaca!.nombre.replaceAll(' ', '_').toLowerCase();
      
      final String path = '${directory.path}/historial_${nombreVaca}_${startDateStr}_a_$endDateStr.csv';
      
      final File file = File(path);
      await file.writeAsString(csvData);

      await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: 'Historial de Ordeño - ${_vaca!.nombre}'));
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_vaca == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Historial de Vaca')),
        body: const Center(child: Text('No se proporcionó una vaca válida.')),
      );
    }

    final String rangoStr = '${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}';

    return Scaffold(
      appBar: AppBar(
        title: Text('Historial - ${_vaca!.nombre}'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Column(
        children: [
          // Selector de Fechas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Última semana'),
                        selected: _currentFilter == FilterType.semana,
                        onSelected: (val) => _aplicarFiltro(FilterType.semana),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Este mes'),
                        selected: _currentFilter == FilterType.mes,
                        onSelected: (val) => _aplicarFiltro(FilterType.mes),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Rango personalizado'),
                        selected: _currentFilter == FilterType.personalizado,
                        onSelected: (val) => _aplicarFiltro(FilterType.personalizado),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.date_range, size: 18, color: Colors.black54),
                    const SizedBox(width: 8),
                    Text(
                      rangoStr,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Contenido Principal
          Expanded(
            child: FutureBuilder<_HistorialVacaData>(
              future: _dataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData) {
                  return const Center(child: Text('Sin datos'));
                }

                final data = snapshot.data!;
                final bool hasRecords = data.registros.isNotEmpty;

                return Column(
                  children: [
                    // Lista de Registros
                    Expanded(
                      child: hasRecords
                          ? ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: data.registros.length,
                              itemBuilder: (context, index) {
                                final r = data.registros[index];
                                String fechaFormateada = r.fecha;
                                try {
                                  final parsedDate = DateFormat('yyyy-MM-dd').parse(r.fecha);
                                  fechaFormateada = DateFormat('dd/MM/yyyy').format(parsedDate);
                                } catch (_) {}

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    leading: const Icon(Icons.water_drop, color: Colors.blueAccent),
                                    title: Text(
                                      '$fechaFormateada - ${r.hora}',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: const Text('Ordeño completado'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${r.litros} L',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            )
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.history_toggle_off, size: 64, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Aún no hay registros de ordeño\npara esta vaca en este rango',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    
                    // Resumen
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildResumenCard(
                                  context,
                                  'Promedio',
                                  '${data.promedio.toStringAsFixed(1)} L',
                                  Icons.analytics,
                                  Colors.blueGrey,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildResumenCard(
                                  context,
                                  'Total',
                                  '${data.totalRango.toStringAsFixed(1)} L',
                                  Icons.opacity,
                                  Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: (hasRecords && !_isExporting) ? () => _exportarCsv(data) : null,
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
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenCard(BuildContext context, String titulo, String valor, IconData icono, Color color) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icono, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              titulo,
              style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              valor,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistorialVacaData {
  final List<RegistroOrdeno> registros;
  final double promedio;
  final double totalRango;

  _HistorialVacaData({
    required this.registros,
    required this.promedio,
    required this.totalRango,
  });
}
