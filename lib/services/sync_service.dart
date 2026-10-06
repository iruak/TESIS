import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/registro_ordeno.dart';
import 'ble_service.dart';
import 'db_service.dart';

/// Resultado de una sincronización.
class SyncResult {
  final int insertados;
  final int duplicados;
  final String fechaHora; // "dd/MM/yyyy HH:mm"

  const SyncResult({
    required this.insertados,
    required this.duplicados,
    required this.fechaHora,
  });
}

/// SyncService escucha los eventos BLE de sincronización (SYNC_DATA / SYNC_END)
/// y los persiste en la base de datos local, evitando duplicados.
///
/// Es un Singleton ChangeNotifier para que la UI pueda suscribirse y
/// reaccionar al estado de sincronización en tiempo real.
class SyncService extends ChangeNotifier {
  // ─── Singleton ────────────────────────────────────────────────
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  // ─── Dependencias ─────────────────────────────────────────────
  final _ble = BleService();
  final _db = DBService();

  // ─── Estado público ───────────────────────────────────────────
  bool sincronizando = false;
  SyncResult? ultimoResultado;

  // ─── Estado interno ───────────────────────────────────────────
  StreamSubscription<String>? _sub;
  int _insertadosParciales = 0;
  int _duplicadosParciales = 0;

  // ─── Inicialización ───────────────────────────────────────────

  /// Llama a [iniciar] una vez al arrancar la app (en main.dart o initState
  /// del primer widget). Es seguro llamarlo múltiples veces, no se suscribe
  /// dos veces.
  void iniciar() {
    _sub?.cancel();
    _sub = _ble.eventStream.listen(_onEvento);
    debugPrint('[SyncService] Escuchando eventos BLE...');
  }

  void _onEvento(String mensaje) {
    debugPrint('[SyncService] Evento recibido: $mensaje');
    final partes = mensaje.split('|');
    if (partes.isEmpty) return;

    switch (partes[0]) {
      case 'SYNC_DATA':
        _procesarSyncData(partes);
        break;
      case 'SYNC_END':
        _procesarSyncEnd();
        break;
      // DONE también pasa por aquí; lo ignoramos (OrdenoScreen lo maneja)
    }
  }

  // ─── Procesamiento SYNC_DATA ──────────────────────────────────

  Future<void> _procesarSyncData(List<String> partes) async {
    // Formato: SYNC_DATA|vacaId|litros|fecha|hora|sincronizado
    if (partes.length < 6) {
      debugPrint('[SyncService] SYNC_DATA mal formado: ${partes.join("|")}');
      return;
    }

    if (!sincronizando) {
      sincronizando = true;
      _insertadosParciales = 0;
      _duplicadosParciales = 0;
      notifyListeners();
    }

    try {
      final vacaId = int.tryParse(partes[1]);
      final litros = double.tryParse(partes[2]);
      final fecha = partes[3];
      final hora = partes[4];
      final sincronizado = int.tryParse(partes[5]) ?? 0;

      if (vacaId == null || litros == null) {
        debugPrint('[SyncService] SYNC_DATA con datos inválidos, ignorando.');
        return;
      }

      final registro = RegistroOrdeno(
        vacaId: vacaId,
        fecha: fecha,
        hora: hora,
        litros: litros,
        sincronizado: sincronizado,
      );

      final insertado = await _db.insertarRegistroSiNoExiste(registro);
      if (insertado) {
        _insertadosParciales++;
        debugPrint('[SyncService] Registro insertado: vaca=$vacaId $fecha $hora ${litros}L');
      } else {
        _duplicadosParciales++;
        debugPrint('[SyncService] Registro duplicado omitido: vaca=$vacaId $fecha $hora');
      }
    } catch (e) {
      debugPrint('[SyncService] Error procesando SYNC_DATA: $e');
    }
  }

  // ─── Procesamiento SYNC_END ───────────────────────────────────

  Future<void> _procesarSyncEnd() async {
    debugPrint('[SyncService] SYNC_END recibido. '
        'Insertados: $_insertadosParciales | Duplicados: $_duplicadosParciales');

    final now = DateTime.now();
    final fechaHora =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // Persistir en DB
    await _db.guardarUltimaSync(fechaHora);

    ultimoResultado = SyncResult(
      insertados: _insertadosParciales,
      duplicados: _duplicadosParciales,
      fechaHora: fechaHora,
    );
    sincronizando = false;
    notifyListeners();

    debugPrint('[SyncService] Sincronización completada: $fechaHora');
  }

  // ─── Limpieza ─────────────────────────────────────────────────

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
