import 'package:flutter/material.dart';
import '../services/db_service.dart';
import '../models/vaca.dart';

class AgregarVacaScreen extends StatefulWidget {
  const AgregarVacaScreen({super.key});

  @override
  State<AgregarVacaScreen> createState() => _AgregarVacaScreenState();
}

class _AgregarVacaScreenState extends State<AgregarVacaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _numeroController = TextEditingController();
  final _razaController = TextEditingController();
  final DBService _dbService = DBService();
  
  List<Vaca> _vacasExistentes = [];
  bool _isLoading = false;
  Vaca? _vacaEnEdicion;

  @override
  void initState() {
    super.initState();
    _cargarVacas();
  }

  Future<void> _cargarVacas() async {
    final vacas = await _dbService.obtenerVacas();
    if (mounted) {
      setState(() {
        _vacasExistentes = vacas;
      });
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _numeroController.dispose();
    _razaController.dispose();
    super.dispose();
  }

  void _limpiarFormulario() {
    _nombreController.clear();
    _numeroController.clear();
    _razaController.clear();
    setState(() {
      _vacaEnEdicion = null;
    });
  }

  void _editarVaca(Vaca vaca) {
    _nombreController.text = vaca.nombre;
    _numeroController.text = vaca.numero;
    _razaController.text = vaca.raza;
    setState(() {
      _vacaEnEdicion = vaca;
    });
  }

  Future<void> _eliminarVaca(Vaca vaca) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Vaca'),
        content: Text('¿Eliminar a ${vaca.nombre}? Esta acción no se puede deshacer y borrará todo su historial de ordeño.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true && vaca.id != null) {
      setState(() => _isLoading = true);
      try {
        await _dbService.eliminarVaca(vaca.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vaca eliminada correctamente')),
          );
          if (_vacaEnEdicion?.id == vaca.id) {
            _limpiarFormulario();
          }
          await _cargarVacas();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  String? _validarNumero(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El número es obligatorio';
    }
    // Verificar si ya existe en otra vaca (excluyendo la que estamos editando)
    final existe = _vacasExistentes.any((v) => 
      v.numero == value.trim() && v.id != _vacaEnEdicion?.id
    );
    if (existe) {
      return 'Este número ya está registrado';
    }
    return null;
  }

  Future<void> _guardar() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final vacaParaGuardar = Vaca(
        id: _vacaEnEdicion?.id, // Mantiene el ID si es actualización
        numero: _numeroController.text.trim(),
        nombre: _nombreController.text.trim(),
        raza: _razaController.text.trim(),
      );

      try {
        if (_vacaEnEdicion == null) {
          await _dbService.insertarVaca(vacaParaGuardar);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Vaca agregada correctamente')),
            );
          }
        } else {
          await _dbService.actualizarVaca(vacaParaGuardar);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Vaca actualizada correctamente')),
            );
          }
        }
        
        _limpiarFormulario();
        await _cargarVacas();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = _vacaEnEdicion != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Vacas'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Formulario
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(esEdicion ? Icons.edit : Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            esEdicion ? 'Editar Vaca' : 'Registrar Nueva Vaca',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const Spacer(),
                          if (esEdicion)
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: _limpiarFormulario,
                              tooltip: 'Cancelar edición',
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _nombreController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                          hintText: 'Ej. Bonita',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.pets),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El nombre es obligatorio';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _numeroController,
                        decoration: const InputDecoration(
                          labelText: 'Número',
                          hintText: 'Ej. 04',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.tag),
                        ),
                        keyboardType: TextInputType.text,
                        validator: _validarNumero,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _razaController,
                        decoration: const InputDecoration(
                          labelText: 'Raza',
                          hintText: 'Ej. Holstein',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.grass),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'La raza es obligatoria';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isLoading ? null : (esEdicion ? _limpiarFormulario : () => Navigator.pop(context)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: Text(esEdicion ? 'Cancelar' : 'Volver'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: FilledButton(
                              onPressed: _isLoading ? null : _guardar,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(esEdicion ? 'Actualizar' : 'Guardar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Lista de vacas existentes
            Row(
              children: [
                const Icon(Icons.list, color: Colors.black54),
                const SizedBox(width: 8),
                Text(
                  'Vacas Registradas (${_vacasExistentes.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_vacasExistentes.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(
                  child: Text('No hay vacas registradas aún.'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _vacasExistentes.length,
                itemBuilder: (context, index) {
                  final vaca = _vacasExistentes[index];
                  final bool seleccionada = _vacaEnEdicion?.id == vaca.id;
                  
                  return Card(
                    color: seleccionada ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3) : null,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: seleccionada ? Theme.of(context).colorScheme.primary : Colors.transparent,
                      ),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                        child: Text(vaca.numero, style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer)),
                      ),
                      title: Text(vaca.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(vaca.raza),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _editarVaca(vaca),
                            tooltip: 'Editar',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _eliminarVaca(vaca),
                            tooltip: 'Eliminar',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
