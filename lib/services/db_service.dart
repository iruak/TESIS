import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/vaca.dart';
import '../models/registro_ordeno.dart';

class DBService {
  // Patrón Singleton para una única instancia de base de datos
  static final DBService _instance = DBService._internal();
  factory DBService() => _instance;
  DBService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'sistema_ordeno.db');

    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE vacas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        numero TEXT NOT NULL,
        nombre TEXT NOT NULL,
        raza TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE registros_ordeno (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vacaId INTEGER NOT NULL,
        fecha TEXT NOT NULL,
        hora TEXT NOT NULL,
        litros REAL NOT NULL,
        sincronizado INTEGER NOT NULL,
        FOREIGN KEY (vacaId) REFERENCES vacas (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE configuracion (
        id INTEGER PRIMARY KEY,
        pin_hash TEXT NOT NULL,
        ultima_sync TEXT,
        pregunta_seguridad TEXT,
        respuesta_seguridad_hash TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE configuracion (
          id INTEGER PRIMARY KEY,
          pin_hash TEXT NOT NULL,
          ultima_sync TEXT,
          pregunta_seguridad TEXT,
          respuesta_seguridad_hash TEXT
        )
      ''');
    }
    if (oldVersion < 3) {
      try {
        await db.execute(
            'ALTER TABLE configuracion ADD COLUMN ultima_sync TEXT');
      } catch (_) {}
    }
    if (oldVersion < 4) {
      try {
        await db.execute(
            'ALTER TABLE configuracion ADD COLUMN pregunta_seguridad TEXT');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE configuracion ADD COLUMN respuesta_seguridad_hash TEXT');
      } catch (_) {}
    }
  }

  // --- Operaciones PIN ---
  
  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  Future<bool> existePin() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM configuracion');
    final count = Sqflite.firstIntValue(result);
    return count != null && count > 0;
  }

  Future<void> guardarPin(String pin) async {
    final db = await database;
    final hash = _hashPin(pin);
    final exists = await existePin();
    if (exists) {
      await db.update('configuracion', {'pin_hash': hash}, where: 'id = 1');
    } else {
      await db.insert('configuracion', {'id': 1, 'pin_hash': hash});
    }
  }

  Future<bool> validarPin(String pin) async {
    final db = await database;
    final hash = _hashPin(pin);
    final List<Map<String, dynamic>> result = await db.query('configuracion', where: 'id = 1');
    if (result.isNotEmpty) {
      return result.first['pin_hash'] == hash;
    }
    return false;
  }

  // --- CRUD Vacas ---

  Future<int> insertarVaca(Vaca vaca) async {
    final db = await database;
    return await db.insert('vacas', vaca.toMap());
  }

  Future<void> actualizarVaca(Vaca vaca) async {
    final db = await database;
    await db.update(
      'vacas',
      vaca.toMap(),
      where: 'id = ?',
      whereArgs: [vaca.id],
    );
  }

  Future<List<Vaca>> obtenerVacas() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('vacas');
    return List.generate(maps.length, (i) {
      return Vaca.fromMap(maps[i]);
    });
  }

  Future<void> eliminarVaca(int id) async {
    final db = await database;
    await db.delete(
      'vacas',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Operaciones de Registros de Ordeño ---

  Future<int> insertarRegistro(RegistroOrdeno registro) async {
    final db = await database;
    return await db.insert('registros_ordeno', registro.toMap());
  }

  Future<List<RegistroOrdeno>> obtenerRegistrosPorFecha(String fecha) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'registros_ordeno',
      where: 'fecha = ?',
      whereArgs: [fecha],
    );
    return List.generate(maps.length, (i) {
      return RegistroOrdeno.fromMap(maps[i]);
    });
  }

  Future<List<RegistroOrdeno>> obtenerRegistrosPorVaca(int vacaId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'registros_ordeno',
      where: 'vacaId = ?',
      whereArgs: [vacaId],
    );
    return List.generate(maps.length, (i) {
      return RegistroOrdeno.fromMap(maps[i]);
    });
  }

  Future<double> obtenerTotalLitrosPorFecha(String fecha) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(litros) as total FROM registros_ordeno WHERE fecha = ?',
      [fecha],
    );
    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }

  Future<double> obtenerPromedioLitrosPorVaca(int vacaId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT AVG(litros) as promedio FROM registros_ordeno WHERE vacaId = ?',
      [vacaId],
    );
    if (result.isNotEmpty && result.first['promedio'] != null) {
      return (result.first['promedio'] as num).toDouble();
    }
    return 0.0;
  }

  Future<double> obtenerTotalMesPorVaca(int vacaId, String anoMes) async {
    final db = await database;
    // anoMes se espera en formato "yyyy-MM" (ej. "2024-03")
    final result = await db.rawQuery(
      'SELECT SUM(litros) as total FROM registros_ordeno WHERE vacaId = ? AND fecha LIKE ?',
      [vacaId, '\$anoMes-%'],
    );
    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }

  Future<List<RegistroOrdeno>> obtenerRegistrosPorVacaYRango(
      int vacaId, String fechaInicio, String fechaFin) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'registros_ordeno',
      where: 'vacaId = ? AND fecha >= ? AND fecha <= ?',
      whereArgs: [vacaId, fechaInicio, fechaFin],
    );
    return List.generate(maps.length, (i) {
      return RegistroOrdeno.fromMap(maps[i]);
    });
  }

  Future<double> obtenerPromedioLitrosPorVacaYRango(
      int vacaId, String fechaInicio, String fechaFin) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT AVG(litros) as promedio FROM registros_ordeno WHERE vacaId = ? AND fecha >= ? AND fecha <= ?',
      [vacaId, fechaInicio, fechaFin],
    );
    if (result.isNotEmpty && result.first['promedio'] != null) {
      return (result.first['promedio'] as num).toDouble();
    }
    return 0.0;
  }

  Future<double> obtenerTotalLitrosPorVacaYRango(
      int vacaId, String fechaInicio, String fechaFin) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(litros) as total FROM registros_ordeno WHERE vacaId = ? AND fecha >= ? AND fecha <= ?',
      [vacaId, fechaInicio, fechaFin],
    );
    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }

  // --- Operaciones de Sincronización ---

  /// Inserta un registro solo si NO existe ya uno con el mismo vacaId+fecha+hora.
  /// Retorna true si se insertó, false si ya existía (duplicado).
  Future<bool> insertarRegistroSiNoExiste(RegistroOrdeno registro) async {
    final db = await database;
    final existing = await db.query(
      'registros_ordeno',
      where: 'vacaId = ? AND fecha = ? AND hora = ?',
      whereArgs: [registro.vacaId, registro.fecha, registro.hora],
    );
    if (existing.isNotEmpty) {
      return false; // ya existe
    }
    await db.insert('registros_ordeno', registro.toMap());
    return true;
  }

  /// Guarda la fecha/hora de la última sincronización en la tabla configuracion.
  Future<void> guardarUltimaSync(String fechaHora) async {
    final db = await database;
    final exists = await existePin(); // reutiliza la fila id=1
    if (exists) {
      await db.rawUpdate(
        'UPDATE configuracion SET ultima_sync = ? WHERE id = 1',
        [fechaHora],
      );
    } else {
      // Si aún no hay fila (caso raro: app sin PIN configurado aún),
      // la creamos solo con el campo ultima_sync.
      await db.rawInsert(
        'INSERT OR IGNORE INTO configuracion (id, pin_hash, ultima_sync) VALUES (1, \'\', ?)',
        [fechaHora],
      );
    }
  }

  /// Lee la fecha/hora de la última sincronización. Devuelve null si nunca se sincronizó.
  Future<String?> obtenerUltimaSync() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT ultima_sync FROM configuracion WHERE id = 1',
    );
    if (result.isNotEmpty && result.first['ultima_sync'] != null) {
      return result.first['ultima_sync'] as String;
    }
    return null;
  }

  // --- Pregunta de Seguridad ---

  /// Guarda la pregunta y respuesta hasheada de seguridad.
  Future<void> guardarPreguntaSeguridad(
      String pregunta, String respuesta) async {
    final db = await database;
    final hash = _hashPin(respuesta.trim().toLowerCase()); // misma función SHA256
    final exists = await existePin();
    if (exists) {
      await db.rawUpdate(
        'UPDATE configuracion SET pregunta_seguridad = ?, respuesta_seguridad_hash = ? WHERE id = 1',
        [pregunta, hash],
      );
    } else {
      await db.rawInsert(
        'INSERT OR IGNORE INTO configuracion (id, pin_hash, pregunta_seguridad, respuesta_seguridad_hash) VALUES (1, \'\', ?, ?)',
        [pregunta, hash],
      );
    }
  }

  /// Devuelve la pregunta de seguridad guardada, o null si no hay ninguna.
  Future<String?> obtenerPreguntaSeguridad() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT pregunta_seguridad FROM configuracion WHERE id = 1',
    );
    if (result.isNotEmpty && result.first['pregunta_seguridad'] != null) {
      return result.first['pregunta_seguridad'] as String;
    }
    return null;
  }

  /// Valida la respuesta a la pregunta de seguridad (case-insensitive, trimmed).
  Future<bool> validarRespuestaSeguridad(String respuesta) async {
    final db = await database;
    final hash = _hashPin(respuesta.trim().toLowerCase());
    final result = await db.rawQuery(
      'SELECT respuesta_seguridad_hash FROM configuracion WHERE id = 1',
    );
    if (result.isNotEmpty && result.first['respuesta_seguridad_hash'] != null) {
      return result.first['respuesta_seguridad_hash'] == hash;
    }
    return false;
  }
}
