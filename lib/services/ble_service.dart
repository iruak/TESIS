import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'db_service.dart';

enum BleConnectionState {
  desconectado,
  buscando,
  conectado
}

class SystemStatus {
  final String bomba;
  final double vacio;
  final int bateria;

  SystemStatus({
    this.bomba = 'OFF',
    this.vacio = 0.0,
    this.bateria = 0,
  });
}

class OrdenoStatus {
  final double litros;
  final String tiempo;

  OrdenoStatus({
    this.litros = 0.0,
    this.tiempo = "00:00:00",
  });
}

class BleService extends ChangeNotifier {
  // Patrón Singleton
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  // BANDERA DE SIMULACIÓN (True = no usa Bluetooth real)
  final bool modoSimulado = true;

  // ESTADO EXPUESTO
  BleConnectionState estadoConexion = BleConnectionState.desconectado;
  SystemStatus systemStatus = SystemStatus();
  OrdenoStatus ordenoStatus = OrdenoStatus();

  // Control de ordeño en curso
  int _vacaIdActual = 0;
  int? get vacaIdEnOrdeno =>
      (_ordenoTimer != null && _ordenoTimer!.isActive && _vacaIdActual != 0)
          ? _vacaIdActual
          : null;
  bool get estaOrdenando => _ordenoTimer != null && _ordenoTimer!.isActive;

  // Stream para eventos puntuales (ej. DONE, SYNC_DATA) que la UI debe escuchar
  final _eventController = StreamController<String>.broadcast();
  Stream<String> get eventStream => _eventController.stream;

  // Variables internas de simulación
  Timer? _statusTimer;
  Timer? _ordenoTimer;
  final Random _rnd = Random();
  int _segundosTranscurridos = 0;
  double _limiteParada = 0;

  // ==========================================
  // MÉTODOS DE CONEXIÓN
  // ==========================================

  Future<void> buscarDispositivo() async {
    debugPrint('[BleService] buscarDispositivo() iniciado. Estado actual: $estadoConexion, Modo simulado: $modoSimulado');
    if (estadoConexion == BleConnectionState.buscando) {
      debugPrint('[BleService] Ya está en proceso de búsqueda, ignorando.');
      return;
    }

    estadoConexion = BleConnectionState.buscando;
    debugPrint('[BleService] Estado cambiado a: buscando');
    notifyListeners();

    if (modoSimulado) {
      debugPrint('[BleService] Simulando búsqueda BLE por 2 segundos...');
      await Future.delayed(Duration(seconds: 2 + _rnd.nextInt(2)));
      debugPrint('[BleService] Búsqueda finalizada. Procediendo a conectar...');
      await conectar();
    } else {
      // TODO: Implementación real de flutter_blue_plus (scan) solo cuando modoSimulado == false
    }
  }

  Future<void> conectar() async {
    debugPrint('[BleService] conectar() iniciado. Modo simulado: $modoSimulado');
    if (modoSimulado) {
      estadoConexion = BleConnectionState.conectado;
      systemStatus = SystemStatus(bomba: 'ON', vacio: 42.0, bateria: 100);
      debugPrint('[BleService] Estado cambiado a: conectado');
      notifyListeners();

      // Simular actualizaciones periódicas del estado del sistema
      _statusTimer?.cancel();
      _statusTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (estadoConexion != BleConnectionState.conectado) {
          timer.cancel();
          return;
        }

        // Vacío oscila entre 40 y 45
        double v = 40.0 + _rnd.nextDouble() * 5.0; 
        // Batería baja muy lentamente
        int b = systemStatus.bateria;
        if (_rnd.nextInt(100) > 80 && b > 0) {
          b--; 
        }
        
        _procesarMensajeEntrante("STATUS|ON|${v.toStringAsFixed(1)}|$b");
      });

      // Simular sincronización de históricos pendientes tras conectar
      Future.delayed(const Duration(seconds: 1), _simularSync);
    } else {
      // TODO: Implementación real de flutter_blue_plus (connect) solo cuando modoSimulado == false
    }
  }

  Future<void> desconectar() async {
    debugPrint('[BleService] desconectar() iniciado');
    if (modoSimulado) {
      _statusTimer?.cancel();
      _statusTimer = null;
      _ordenoTimer?.cancel();
      _ordenoTimer = null;
      _vacaIdActual = 0;
      
      estadoConexion = BleConnectionState.desconectado;
      systemStatus = SystemStatus();
      ordenoStatus = OrdenoStatus();
      debugPrint('[BleService] Estado cambiado a: desconectado');
      notifyListeners();
    } else {
      // TODO: Implementación real de flutter_blue_plus (disconnect) solo cuando modoSimulado == false
    }
  }

  // ==========================================
  // MÉTODOS DE OPERACIÓN
  // ==========================================

  Future<void> enviarComando(String comando) async {
    debugPrint('[BleService] BLE Enviando: $comando');
    if (!modoSimulado) {
      // TODO: Escribir en la característica TX del ESP32 solo cuando modoSimulado == false
    }
  }

  Future<void> iniciarOrdeno(int vacaId) async {
    debugPrint('[BleService] iniciarOrdeno() para vacaId: $vacaId');
    enviarComando("NEXT|$vacaId");
    
    if (modoSimulado) {
      _ordenoTimer?.cancel();
      _ordenoTimer = null;
      
      _vacaIdActual = vacaId;
      _segundosTranscurridos = 0;
      ordenoStatus = OrdenoStatus();
      
      // La máquina parará automáticamente entre 6 y 10 litros
      _limiteParada = 6.0 + _rnd.nextDouble() * 4.0; 
      debugPrint('[BleService] Ordeño simulado iniciado con límite de parada: ${_limiteParada.toStringAsFixed(2)} L');
      
      notifyListeners();
      
      _ordenoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _segundosTranscurridos++;
        
        // El flujo sube entre 0.05 y 0.15 litros por segundo
        double incremento = 0.05 + _rnd.nextDouble() * 0.10;
        double nuevosLitros = ordenoStatus.litros + incremento;
        
        String tiempoStr = _formatTime(_segundosTranscurridos);
        
        // Simular que el ESP32 nos manda mensaje FLOW
        _procesarMensajeEntrante("FLOW|${nuevosLitros.toStringAsFixed(2)}|$tiempoStr");

        // Simular la parada por bajo flujo
        if (nuevosLitros >= _limiteParada) {
          timer.cancel();
          _ordenoTimer = null;
          final vacaTerminada = _vacaIdActual;
          _vacaIdActual = 0;
          
          final now = DateTime.now();
          final fecha = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
          final hora = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
          
          debugPrint('[BleService] Límite alcanzado ($nuevosLitros L). Emitiendo DONE para vaca $vacaTerminada');
          _procesarMensajeEntrante("DONE|$vacaTerminada|${nuevosLitros.toStringAsFixed(2)}|$fecha|$hora");
          notifyListeners();
        }
      });
    }
  }

  Future<void> pararEmergencia() async {
    debugPrint('[BleService] pararEmergencia() llamado');
    enviarComando("STOP");
    if (modoSimulado) {
      _ordenoTimer?.cancel();
      _ordenoTimer = null;
      _vacaIdActual = 0;
      debugPrint('[BleService] Timer de ordeño cancelado y estado reseteado');
      notifyListeners();
    }
  }

  // ==========================================
  // SIMULACIÓN DE SINCRONIZACIÓN
  // ==========================================

  /// Emite entre 0 y 3 registros SYNC_DATA ficticios usando las vacas reales
  /// de la DB, seguidos de un SYNC_END. Solo en modoSimulado.
  Future<void> _simularSync() async {
    if (!modoSimulado) return;
    debugPrint('[BleService] Iniciando simulación de sincronización...');

    try {
      final vacas = await DBService().obtenerVacas();
      if (vacas.isEmpty) {
        debugPrint('[BleService] No hay vacas registradas, enviando SYNC_END sin datos.');
        _procesarMensajeEntrante('SYNC_END');
        return;
      }

      final cantidad = _rnd.nextInt(4); // 0, 1, 2 o 3 registros
      debugPrint('[BleService] Simulando $cantidad registro(s) de sincronización...');

      for (int i = 0; i < cantidad; i++) {
        await Future.delayed(const Duration(milliseconds: 300));
        final vaca = vacas[_rnd.nextInt(vacas.length)];
        final diasAtras = _rnd.nextInt(5) + 1; // entre 1 y 5 días atrás
        final fecha = DateTime.now().subtract(Duration(days: diasAtras));
        final fechaStr =
            '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
        final hora = '0${_rnd.nextInt(2) + 5}:${_rnd.nextInt(60).toString().padLeft(2, '0')}';
        final litros = (5.0 + _rnd.nextDouble() * 5.0).toStringAsFixed(2);
        final msg = 'SYNC_DATA|${vaca.id}|$litros|$fechaStr|$hora|0';
        debugPrint('[BleService] Emitiendo: $msg');
        _procesarMensajeEntrante(msg);
      }

      await Future.delayed(const Duration(milliseconds: 300));
      debugPrint('[BleService] Emitiendo SYNC_END');
      _procesarMensajeEntrante('SYNC_END');
    } catch (e) {
      debugPrint('[BleService] Error en _simularSync: $e');
      _procesarMensajeEntrante('SYNC_END');
    }
  }

  // ==========================================
  // PROCESAMIENTO DE PROTOCOLO ESP32 -> APP
  // ==========================================

  void _procesarMensajeEntrante(String mensaje) {
    debugPrint('[BleService] BLE Recibido: $mensaje');
    final partes = mensaje.split('|');
    if (partes.isEmpty) return;

    final comando = partes[0];

    switch (comando) {
      case 'FLOW':
        if (partes.length >= 3) {
          ordenoStatus = OrdenoStatus(
            litros: double.tryParse(partes[1]) ?? ordenoStatus.litros,
            tiempo: partes[2],
          );
          notifyListeners();
        }
        break;
        
      case 'STATUS':
        if (partes.length >= 4) {
          systemStatus = SystemStatus(
            bomba: partes[1],
            vacio: double.tryParse(partes[2]) ?? systemStatus.vacio,
            bateria: int.tryParse(partes[3]) ?? systemStatus.bateria,
          );
          notifyListeners();
        }
        break;

      case 'DONE':
      case 'SYNC_DATA':
      case 'SYNC_END':
        _eventController.add(mensaje);
        break;
    }
  }

  // ==========================================
  // UTILIDADES
  // ==========================================

  String _formatTime(int totalSeconds) {
    int h = totalSeconds ~/ 3600;
    int m = (totalSeconds % 3600) ~/ 60;
    int s = totalSeconds % 60;
    
    // Formato HH:mm:ss según el requerimiento
    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }
}
