import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/vaca.dart';
import '../models/registro_ordeno.dart';

class ReporteExcelService {
  static final colorVerdeOscuro = ExcelColor.fromHexString("FF2E7D32");
  static final colorVerdeClaro = ExcelColor.fromHexString("FFC8E6C9");
  static final colorVerdeSuave = ExcelColor.fromHexString("FFE8F5E9");
  static final colorBlanco = ExcelColor.white;
  static final colorBorde = ExcelColor.fromHexString("FFD6D6D6");
  static final colorFondoEtiqueta = ExcelColor.fromHexString("FFF5F5F5");

  static final bordeFino = Border(
    borderStyle: BorderStyle.Thin,
    borderColorHex: colorBorde,
  );

  static final estiloTituloPrincipal = CellStyle(
    fontColorHex: colorBlanco,
    backgroundColorHex: colorVerdeOscuro,
    bold: true,
    fontSize: 13,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
  );

  static final estiloEncabezadoTabla = CellStyle(
    fontColorHex: colorBlanco,
    backgroundColorHex: colorVerdeOscuro,
    bold: true,
    fontSize: 11,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    leftBorder: bordeFino,
    rightBorder: bordeFino,
    topBorder: bordeFino,
    bottomBorder: bordeFino,
  );

  static final estiloEncabezadoDia = CellStyle(
    fontColorHex: ExcelColor.black,
    backgroundColorHex: colorVerdeClaro,
    bold: true,
    fontSize: 11,
    horizontalAlign: HorizontalAlign.Left,
    verticalAlign: VerticalAlign.Center,
    leftBorder: bordeFino,
    rightBorder: bordeFino,
    topBorder: bordeFino,
    bottomBorder: bordeFino,
  );

  static final estiloEtiquetaResumen = CellStyle(
    backgroundColorHex: colorFondoEtiqueta,
    bold: true,
    fontSize: 10,
    horizontalAlign: HorizontalAlign.Left,
    verticalAlign: VerticalAlign.Center,
    leftBorder: bordeFino,
    rightBorder: bordeFino,
    topBorder: bordeFino,
    bottomBorder: bordeFino,
  );

  static final estiloValorResumen = CellStyle(
    bold: false,
    fontSize: 10,
    horizontalAlign: HorizontalAlign.Left,
    verticalAlign: VerticalAlign.Center,
    leftBorder: bordeFino,
    rightBorder: bordeFino,
    topBorder: bordeFino,
    bottomBorder: bordeFino,
  );

  static final estiloDatoTextoCentrado = CellStyle(
    fontSize: 10,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    leftBorder: bordeFino,
    rightBorder: bordeFino,
    topBorder: bordeFino,
    bottomBorder: bordeFino,
  );

  static final estiloDatoTextoIzquierda = CellStyle(
    fontSize: 10,
    horizontalAlign: HorizontalAlign.Left,
    verticalAlign: VerticalAlign.Center,
    leftBorder: bordeFino,
    rightBorder: bordeFino,
    topBorder: bordeFino,
    bottomBorder: bordeFino,
  );

  static final estiloDatoNumero = CellStyle(
    fontSize: 10,
    horizontalAlign: HorizontalAlign.Right,
    verticalAlign: VerticalAlign.Center,
    leftBorder: bordeFino,
    rightBorder: bordeFino,
    topBorder: bordeFino,
    bottomBorder: bordeFino,
  );

  static final estiloFilaTotal = CellStyle(
    backgroundColorHex: colorVerdeSuave,
    bold: true,
    fontSize: 10,
    horizontalAlign: HorizontalAlign.Right,
    verticalAlign: VerticalAlign.Center,
    leftBorder: bordeFino,
    rightBorder: bordeFino,
    topBorder: bordeFino,
    bottomBorder: bordeFino,
  );

  static final estiloFilaTotalCentrado = CellStyle(
    backgroundColorHex: colorVerdeSuave,
    bold: true,
    fontSize: 10,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    leftBorder: bordeFino,
    rightBorder: bordeFino,
    topBorder: bordeFino,
    bottomBorder: bordeFino,
  );

  static void writeCell(
    Sheet sheet, {
    required int col,
    required int row,
    required CellValue value,
    required CellStyle style,
  }) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = value;
    cell.cellStyle = style;
  }

  static void mergeWithStyle(
    Sheet sheet, {
    required int startCol,
    required int startRow,
    required int endCol,
    required int endRow,
    required CellValue value,
    required CellStyle style,
  }) {
    for (int r = startRow; r <= endRow; r++) {
      for (int c = startCol; c <= endCol; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
        cell.cellStyle = style;
        if (r == startRow && c == startCol) {
          cell.value = value;
        }
      }
    }
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: startRow),
      CellIndex.indexByColumnRow(columnIndex: endCol, rowIndex: endRow),
    );
  }

  static String nombreDiaEspanol(DateTime dt) {
    const dias = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    return dias[dt.weekday - 1];
  }

  static String nombreMesEspanol(int month) {
    const meses = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return meses[month - 1];
  }

  /// Genera el archivo Excel (.xlsx) con el Reporte General Mensual
  /// con Hoja 1 ("Reporte General") y Hoja 2 ("Resumen por vaca").
  static Future<String> generarReporteGeneralMensual({
    required DateTime mes,
    required List<Vaca> vacas,
    required List<RegistroOrdeno> registros,
  }) async {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    excel.rename(defaultSheet ?? 'Sheet1', 'Reporte General');

    final sheet1 = excel['Reporte General'];
    final sheet2 = excel['Resumen por vaca'];

    final fechaInicioMes = DateTime(mes.year, mes.month, 1);
    final fechaFinMes = DateTime(mes.year, mes.month + 1, 0);

    // Mapa de vacas para búsqueda rápida
    final Map<int, Vaca> mapaVacas = {for (final v in vacas) if (v.id != null) v.id!: v};

    // Estadísticas generales del mes
    final diasConOrdeno = registros.map((r) => r.fecha).toSet();
    final vacasOrdenadasEnMes = registros.map((r) => r.vacaId).toSet();
    final double totalLitrosMes = registros.fold(0.0, (acc, r) => acc + r.litros);
    final double promedioDiario =
        diasConOrdeno.isNotEmpty ? totalLitrosMes / diasConOrdeno.length : 0.0;
    final double promedioPorVaca =
        vacasOrdenadasEnMes.isNotEmpty ? totalLitrosMes / vacasOrdenadasEnMes.length : 0.0;
    final horaEmision = DateFormat('HH:mm').format(DateTime.now());

    // ══════════════════════════════════════════════════════════════
    // HOJA 1: REPORTE GENERAL
    // ══════════════════════════════════════════════════════════════

    // Fila 1: Título combinado
    mergeWithStyle(
      sheet1,
      startCol: 0,
      startRow: 0,
      endCol: 6,
      endRow: 0,
      value: TextCellValue('SISTEMA DE ORDEÑO INTELIGENTE - REPORTE GENERAL MENSUAL'),
      style: estiloTituloPrincipal,
    );

    // Filas 3 a 6: Resumen general en dos columnas
    final periodoStr =
        '${DateFormat('dd/MM/yyyy').format(fechaInicioMes)} - ${DateFormat('dd/MM/yyyy').format(fechaFinMes)}';

    // Fila 3
    writeCell(sheet1, col: 0, row: 2, value: TextCellValue('Período:'), style: estiloEtiquetaResumen);
    writeCell(sheet1, col: 1, row: 2, value: TextCellValue(periodoStr), style: estiloValorResumen);
    writeCell(sheet1, col: 3, row: 2, value: TextCellValue('Hora de emisión:'), style: estiloEtiquetaResumen);
    writeCell(sheet1, col: 4, row: 2, value: TextCellValue(horaEmision), style: estiloValorResumen);

    // Fila 4
    writeCell(sheet1, col: 0, row: 3, value: TextCellValue('Total de vacas en finca:'), style: estiloEtiquetaResumen);
    writeCell(sheet1, col: 1, row: 3, value: IntCellValue(vacas.length), style: estiloValorResumen);
    writeCell(sheet1, col: 3, row: 3, value: TextCellValue('Días con ordeño:'), style: estiloEtiquetaResumen);
    writeCell(sheet1, col: 4, row: 3, value: IntCellValue(diasConOrdeno.length), style: estiloValorResumen);

    // Fila 5
    writeCell(sheet1, col: 0, row: 4, value: TextCellValue('Total producción del mes (L):'), style: estiloEtiquetaResumen);
    writeCell(sheet1, col: 1, row: 4, value: DoubleCellValue(double.parse(totalLitrosMes.toStringAsFixed(2))), style: estiloValorResumen);
    writeCell(sheet1, col: 3, row: 4, value: TextCellValue('Promedio diario (L):'), style: estiloEtiquetaResumen);
    writeCell(sheet1, col: 4, row: 4, value: DoubleCellValue(double.parse(promedioDiario.toStringAsFixed(2))), style: estiloValorResumen);

    // Fila 6
    writeCell(sheet1, col: 0, row: 5, value: TextCellValue('Promedio por vaca ordeñada (L):'), style: estiloEtiquetaResumen);
    writeCell(sheet1, col: 1, row: 5, value: DoubleCellValue(double.parse(promedioPorVaca.toStringAsFixed(2))), style: estiloValorResumen);
    writeCell(sheet1, col: 3, row: 5, value: TextCellValue('Vacas ordeñadas en el mes:'), style: estiloEtiquetaResumen);
    writeCell(sheet1, col: 4, row: 5, value: IntCellValue(vacasOrdenadasEnMes.length), style: estiloValorResumen);

    // Agrupar registros por día
    final Map<String, List<RegistroOrdeno>> registrosPorDia = {};
    for (final r in registros) {
      registrosPorDia.putIfAbsent(r.fecha, () => []).add(r);
    }
    final diasOrdenados = registrosPorDia.keys.toList()..sort();

    int filaActual = 7; // Fila 8 en Excel (0-indexed = 7)

    final List<String> encabezadosColumnas = [
      'N°',
      'Vaca',
      'N° Arete',
      'Raza',
      'Hora ordeño',
      'Producción (L)',
      'Estado',
    ];

    for (final dia in diasOrdenados) {
      final registrosDelDia = registrosPorDia[dia]!;
      registrosDelDia.sort((a, b) => a.hora.compareTo(b.hora));

      DateTime dtDia;
      try {
        dtDia = DateTime.parse(dia);
      } catch (_) {
        dtDia = DateTime.now();
      }

      final diaSemana = nombreDiaEspanol(dtDia);
      final diaFmt = DateFormat('dd/MM/yyyy').format(dtDia);

      // Fila de encabezado del día
      mergeWithStyle(
        sheet1,
        startCol: 0,
        startRow: filaActual,
        endCol: 6,
        endRow: filaActual,
        value: TextCellValue('$diaSemana $diaFmt'),
        style: estiloEncabezadoDia,
      );
      filaActual++;

      // Fila de columnas
      for (int c = 0; c < encabezadosColumnas.length; c++) {
        writeCell(
          sheet1,
          col: c,
          row: filaActual,
          value: TextCellValue(encabezadosColumnas[c]),
          style: estiloEncabezadoTabla,
        );
      }
      filaActual++;

      // Filas de vacas ordeñadas ese día
      double sumaDia = 0.0;
      int idxVacaDia = 1;
      for (final r in registrosDelDia) {
        final vaca = mapaVacas[r.vacaId];
        sumaDia += r.litros;

        writeCell(sheet1, col: 0, row: filaActual, value: IntCellValue(idxVacaDia++), style: estiloDatoTextoCentrado);
        writeCell(sheet1, col: 1, row: filaActual, value: TextCellValue(vaca?.nombre ?? 'Desconocida'), style: estiloDatoTextoIzquierda);
        writeCell(sheet1, col: 2, row: filaActual, value: TextCellValue(vaca?.numero ?? '--'), style: estiloDatoTextoCentrado);
        writeCell(sheet1, col: 3, row: filaActual, value: TextCellValue(vaca?.raza ?? '--'), style: estiloDatoTextoIzquierda);
        writeCell(sheet1, col: 4, row: filaActual, value: TextCellValue(r.hora), style: estiloDatoTextoCentrado);
        writeCell(sheet1, col: 5, row: filaActual, value: DoubleCellValue(double.parse(r.litros.toStringAsFixed(2))), style: estiloDatoNumero);
        writeCell(sheet1, col: 6, row: filaActual, value: TextCellValue('Completado'), style: estiloDatoTextoCentrado);
        filaActual++;
      }

      // Fila "TOTAL DEL DÍA"
      mergeWithStyle(
        sheet1,
        startCol: 0,
        startRow: filaActual,
        endCol: 4,
        endRow: filaActual,
        value: TextCellValue('TOTAL DEL DÍA:'),
        style: estiloFilaTotal,
      );
      writeCell(sheet1, col: 5, row: filaActual, value: DoubleCellValue(double.parse(sumaDia.toStringAsFixed(2))), style: estiloFilaTotal);
      writeCell(sheet1, col: 6, row: filaActual, value: TextCellValue('L'), style: estiloFilaTotalCentrado);
      filaActual += 2; // Fila en blanco antes del siguiente día
    }

    // Bloque RESUMEN FINAL DEL MES
    mergeWithStyle(
      sheet1,
      startCol: 0,
      startRow: filaActual,
      endCol: 6,
      endRow: filaActual,
      value: TextCellValue('RESUMEN FINAL DEL MES'),
      style: estiloEncabezadoTabla,
    );
    filaActual++;

    mergeWithStyle(
      sheet1,
      startCol: 0,
      startRow: filaActual,
      endCol: 4,
      endRow: filaActual,
      value: TextCellValue('TOTAL LITROS DEL MES:'),
      style: estiloFilaTotal,
    );
    writeCell(sheet1, col: 5, row: filaActual, value: DoubleCellValue(double.parse(totalLitrosMes.toStringAsFixed(2))), style: estiloFilaTotal);
    writeCell(sheet1, col: 6, row: filaActual, value: TextCellValue('L'), style: estiloFilaTotalCentrado);
    filaActual++;

    mergeWithStyle(
      sheet1,
      startCol: 0,
      startRow: filaActual,
      endCol: 4,
      endRow: filaActual,
      value: TextCellValue('PROMEDIO POR DÍA CON ORDEÑO:'),
      style: estiloFilaTotal,
    );
    writeCell(sheet1, col: 5, row: filaActual, value: DoubleCellValue(double.parse(promedioDiario.toStringAsFixed(2))), style: estiloFilaTotal);
    writeCell(sheet1, col: 6, row: filaActual, value: TextCellValue('L/día'), style: estiloFilaTotalCentrado);
    filaActual++;

    mergeWithStyle(
      sheet1,
      startCol: 0,
      startRow: filaActual,
      endCol: 4,
      endRow: filaActual,
      value: TextCellValue('PROMEDIO POR VACA ORDEÑADA:'),
      style: estiloFilaTotal,
    );
    writeCell(sheet1, col: 5, row: filaActual, value: DoubleCellValue(double.parse(promedioPorVaca.toStringAsFixed(2))), style: estiloFilaTotal);
    writeCell(sheet1, col: 6, row: filaActual, value: TextCellValue('L/vaca'), style: estiloFilaTotalCentrado);

    // Ajustar anchos de columnas Hoja 1
    sheet1.setColumnWidth(0, 8.0);
    sheet1.setColumnWidth(1, 24.0);
    sheet1.setColumnWidth(2, 16.0);
    sheet1.setColumnWidth(3, 18.0);
    sheet1.setColumnWidth(4, 16.0);
    sheet1.setColumnWidth(5, 18.0);
    sheet1.setColumnWidth(6, 16.0);

    // ══════════════════════════════════════════════════════════════
    // HOJA 2: RESUMEN POR VACA
    // ══════════════════════════════════════════════════════════════

    mergeWithStyle(
      sheet2,
      startCol: 0,
      startRow: 0,
      endCol: 6,
      endRow: 0,
      value: TextCellValue('SISTEMA DE ORDEÑO INTELIGENTE - RESUMEN POR VACA'),
      style: estiloTituloPrincipal,
    );

    final mesNombreStr = '${nombreMesEspanol(mes.month)} ${mes.year}'.toUpperCase();
    writeCell(sheet2, col: 0, row: 2, value: TextCellValue('Mes evaluado:'), style: estiloEtiquetaResumen);
    writeCell(sheet2, col: 1, row: 2, value: TextCellValue(mesNombreStr), style: estiloValorResumen);
    writeCell(sheet2, col: 3, row: 2, value: TextCellValue('Fecha de emisión:'), style: estiloEtiquetaResumen);
    writeCell(sheet2, col: 4, row: 2, value: TextCellValue(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())), style: estiloValorResumen);

    final List<String> encabezadosHoja2 = [
      'N°',
      'N° Arete / RFID',
      'Nombre de la Vaca',
      'Raza',
      'Ordeños en el Mes',
      'Total Producción (L)',
      'Promedio por Ordeño (L)',
    ];

    int filaHoja2 = 4;
    for (int c = 0; c < encabezadosHoja2.length; c++) {
      writeCell(
        sheet2,
        col: c,
        row: filaHoja2,
        value: TextCellValue(encabezadosHoja2[c]),
        style: estiloEncabezadoTabla,
      );
    }
    filaHoja2++;

    int totalSesionesTodas = 0;
    int idxVacaH2 = 1;

    for (final vaca in vacas) {
      final registrosDeVaca = registros.where((r) => r.vacaId == vaca.id).toList();
      final numOrdenos = registrosDeVaca.length;
      totalSesionesTodas += numOrdenos;
      final double totalLitrosVaca = registrosDeVaca.fold(0.0, (acc, r) => acc + r.litros);
      final double promedioVaca = numOrdenos > 0 ? totalLitrosVaca / numOrdenos : 0.0;

      writeCell(sheet2, col: 0, row: filaHoja2, value: IntCellValue(idxVacaH2++), style: estiloDatoTextoCentrado);
      writeCell(sheet2, col: 1, row: filaHoja2, value: TextCellValue(vaca.numero), style: estiloDatoTextoCentrado);
      writeCell(sheet2, col: 2, row: filaHoja2, value: TextCellValue(vaca.nombre), style: estiloDatoTextoIzquierda);
      writeCell(sheet2, col: 3, row: filaHoja2, value: TextCellValue(vaca.raza), style: estiloDatoTextoIzquierda);
      writeCell(sheet2, col: 4, row: filaHoja2, value: IntCellValue(numOrdenos), style: estiloDatoTextoCentrado);
      writeCell(sheet2, col: 5, row: filaHoja2, value: DoubleCellValue(double.parse(totalLitrosVaca.toStringAsFixed(2))), style: estiloDatoNumero);
      writeCell(sheet2, col: 6, row: filaHoja2, value: DoubleCellValue(double.parse(promedioVaca.toStringAsFixed(2))), style: estiloDatoNumero);
      filaHoja2++;
    }

    // Fila TOTAL GENERAL en Hoja 2
    final double promedioGeneral =
        totalSesionesTodas > 0 ? totalLitrosMes / totalSesionesTodas : 0.0;

    mergeWithStyle(
      sheet2,
      startCol: 0,
      startRow: filaHoja2,
      endCol: 3,
      endRow: filaHoja2,
      value: TextCellValue('TOTAL GENERAL:'),
      style: estiloFilaTotal,
    );
    writeCell(sheet2, col: 4, row: filaHoja2, value: IntCellValue(totalSesionesTodas), style: estiloFilaTotalCentrado);
    writeCell(sheet2, col: 5, row: filaHoja2, value: DoubleCellValue(double.parse(totalLitrosMes.toStringAsFixed(2))), style: estiloFilaTotal);
    writeCell(sheet2, col: 6, row: filaHoja2, value: DoubleCellValue(double.parse(promedioGeneral.toStringAsFixed(2))), style: estiloFilaTotal);

    // Ajustar anchos de columnas Hoja 2
    sheet2.setColumnWidth(0, 8.0);
    sheet2.setColumnWidth(1, 18.0);
    sheet2.setColumnWidth(2, 24.0);
    sheet2.setColumnWidth(3, 18.0);
    sheet2.setColumnWidth(4, 18.0);
    sheet2.setColumnWidth(5, 22.0);
    sheet2.setColumnWidth(6, 24.0);

    // ══════════════════════════════════════════════════════════════
    // GUARDADO DEL ARCHIVO
    // ══════════════════════════════════════════════════════════════
    final List<int>? fileBytes = excel.save();
    if (fileBytes == null) {
      throw Exception('No se pudo generar el contenido del archivo Excel.');
    }

    final directory = await getTemporaryDirectory();
    final anoMesStr = DateFormat('yyyy-MM').format(mes);
    final path = '${directory.path}/reporte_general_$anoMesStr.xlsx';
    final file = File(path);
    await file.writeAsBytes(fileBytes, flush: true);

    return path;
  }

  /// Genera el archivo Excel (.xlsx) con el historial individual de una vaca
  static Future<String> generarReporteVacaIndividual({
    required Vaca vaca,
    required DateTime fechaInicio,
    required DateTime fechaFin,
    required List<RegistroOrdeno> registros,
    required double total,
    required double promedio,
  }) async {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    excel.rename(defaultSheet ?? 'Sheet1', 'Historial de Ordeño');

    final sheet = excel['Historial de Ordeño'];

    // Fila 1: Título combinado
    mergeWithStyle(
      sheet,
      startCol: 0,
      startRow: 0,
      endCol: 6,
      endRow: 0,
      value: TextCellValue('SISTEMA DE ORDEÑO INTELIGENTE - HISTORIAL INDIVIDUAL'),
      style: estiloTituloPrincipal,
    );

    final rangoStr =
        '${DateFormat('dd/MM/yyyy').format(fechaInicio)} al ${DateFormat('dd/MM/yyyy').format(fechaFin)}';
    final horaEmision = DateFormat('HH:mm').format(DateTime.now());

    // Fila 3
    writeCell(sheet, col: 0, row: 2, value: TextCellValue('Vaca:'), style: estiloEtiquetaResumen);
    writeCell(sheet, col: 1, row: 2, value: TextCellValue(vaca.nombre), style: estiloValorResumen);
    writeCell(sheet, col: 3, row: 2, value: TextCellValue('N° Arete / RFID:'), style: estiloEtiquetaResumen);
    writeCell(sheet, col: 4, row: 2, value: TextCellValue(vaca.numero), style: estiloValorResumen);

    // Fila 4
    writeCell(sheet, col: 0, row: 3, value: TextCellValue('Raza:'), style: estiloEtiquetaResumen);
    writeCell(sheet, col: 1, row: 3, value: TextCellValue(vaca.raza), style: estiloValorResumen);
    writeCell(sheet, col: 3, row: 3, value: TextCellValue('Período evaluado:'), style: estiloEtiquetaResumen);
    writeCell(sheet, col: 4, row: 3, value: TextCellValue(rangoStr), style: estiloValorResumen);

    // Fila 5
    writeCell(sheet, col: 0, row: 4, value: TextCellValue('Total producción (L):'), style: estiloEtiquetaResumen);
    writeCell(sheet, col: 1, row: 4, value: DoubleCellValue(double.parse(total.toStringAsFixed(2))), style: estiloValorResumen);
    writeCell(sheet, col: 3, row: 4, value: TextCellValue('Promedio por ordeño (L):'), style: estiloEtiquetaResumen);
    writeCell(sheet, col: 4, row: 4, value: DoubleCellValue(double.parse(promedio.toStringAsFixed(2))), style: estiloValorResumen);

    // Fila 6
    writeCell(sheet, col: 0, row: 5, value: TextCellValue('Total de ordeños:'), style: estiloEtiquetaResumen);
    writeCell(sheet, col: 1, row: 5, value: IntCellValue(registros.length), style: estiloValorResumen);
    writeCell(sheet, col: 3, row: 5, value: TextCellValue('Hora de emisión:'), style: estiloEtiquetaResumen);
    writeCell(sheet, col: 4, row: 5, value: TextCellValue(horaEmision), style: estiloValorResumen);

    final List<String> encabezados = [
      'N°',
      'Fecha',
      'Día',
      'Hora',
      'Producción (L)',
      'Estado',
      'Sincronización',
    ];

    int filaActual = 7;
    for (int c = 0; c < encabezados.length; c++) {
      writeCell(
        sheet,
        col: c,
        row: filaActual,
        value: TextCellValue(encabezados[c]),
        style: estiloEncabezadoTabla,
      );
    }
    filaActual++;

    int idx = 1;
    for (final r in registros) {
      DateTime dtReg;
      try {
        dtReg = DateTime.parse(r.fecha);
      } catch (_) {
        dtReg = DateTime.now();
      }

      final fechaFmt = DateFormat('dd/MM/yyyy').format(dtReg);
      final diaSemana = nombreDiaEspanol(dtReg);
      final sincroStr = r.sincronizado == 1 ? 'Sincronizado' : 'Local';

      writeCell(sheet, col: 0, row: filaActual, value: IntCellValue(idx++), style: estiloDatoTextoCentrado);
      writeCell(sheet, col: 1, row: filaActual, value: TextCellValue(fechaFmt), style: estiloDatoTextoCentrado);
      writeCell(sheet, col: 2, row: filaActual, value: TextCellValue(diaSemana), style: estiloDatoTextoIzquierda);
      writeCell(sheet, col: 3, row: filaActual, value: TextCellValue(r.hora), style: estiloDatoTextoCentrado);
      writeCell(sheet, col: 4, row: filaActual, value: DoubleCellValue(double.parse(r.litros.toStringAsFixed(2))), style: estiloDatoNumero);
      writeCell(sheet, col: 5, row: filaActual, value: TextCellValue('Completado'), style: estiloDatoTextoCentrado);
      writeCell(sheet, col: 6, row: filaActual, value: TextCellValue(sincroStr), style: estiloDatoTextoCentrado);
      filaActual++;
    }

    // Fila Total Acumulado
    mergeWithStyle(
      sheet,
      startCol: 0,
      startRow: filaActual,
      endCol: 3,
      endRow: filaActual,
      value: TextCellValue('TOTAL ACUMULADO:'),
      style: estiloFilaTotal,
    );
    writeCell(sheet, col: 4, row: filaActual, value: DoubleCellValue(double.parse(total.toStringAsFixed(2))), style: estiloFilaTotal);
    writeCell(sheet, col: 5, row: filaActual, value: TextCellValue('L'), style: estiloFilaTotalCentrado);
    writeCell(sheet, col: 6, row: filaActual, value: TextCellValue(''), style: estiloFilaTotal);

    sheet.setColumnWidth(0, 8.0);
    sheet.setColumnWidth(1, 16.0);
    sheet.setColumnWidth(2, 16.0);
    sheet.setColumnWidth(3, 14.0);
    sheet.setColumnWidth(4, 18.0);
    sheet.setColumnWidth(5, 16.0);
    sheet.setColumnWidth(6, 18.0);

    final List<int>? fileBytes = excel.save();
    if (fileBytes == null) {
      throw Exception('No se pudo generar el contenido del archivo Excel.');
    }

    final directory = await getTemporaryDirectory();
    final String startFileStr = DateFormat('yyyy-MM-dd').format(fechaInicio);
    final String endFileStr = DateFormat('yyyy-MM-dd').format(fechaFin);
    final String nombreLimpio = vaca.nombre.replaceAll(' ', '_').toLowerCase();

    final path = '${directory.path}/reporte_vaca_${nombreLimpio}_${startFileStr}_a_$endFileStr.xlsx';
    final file = File(path);
    await file.writeAsBytes(fileBytes, flush: true);

    return path;
  }
}
