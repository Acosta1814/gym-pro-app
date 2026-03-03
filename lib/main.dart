import 'package:flutter/material.dart';

void main() {
  runApp(const GymApp());
}

// ==========================================
// MODELOS DE DATOS
// ==========================================
class Ejercicio {
  String nombre;
  String series;
  String repeticiones;
  String peso;
  String unidad;

  Ejercicio({
    required this.nombre,
    required this.series,
    required this.repeticiones,
    required this.peso,
    required this.unidad,
  });
}

class Rutina {
  String nombre;
  List<Ejercicio> ejercicios;

  Rutina({required this.nombre, required this.ejercicios});
}

// ==========================================
// CONFIGURACIÓN PRINCIPAL
// ==========================================
class GymApp extends StatelessWidget {
  const GymApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'My Gym App',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueAccent,
          surface: Color(0xFF1E1E1E),
          onSurface: Colors.white,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.black,
          selectedItemColor: Colors.blueAccent,
          unselectedItemColor: Colors.grey,
        ),
      ),
      home: const MainNavigator(),
    );
  }
}

// ==========================================
// CONTROLADOR DE ESTADO (MAIN NAVIGATOR)
// ==========================================
class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _currentIndex = 0;

  final List<Rutina> _rutinas = [
    Rutina(
      nombre: 'Día de Pecho y Tríceps',
      ejercicios: [
        Ejercicio(
          nombre: 'Press de Banca',
          series: '4',
          repeticiones: '10',
          peso: '60',
          unidad: 'kg',
        ),
        Ejercicio(
          nombre: 'Fondos',
          series: '3',
          repeticiones: '12',
          peso: '0',
          unidad: 'kg',
        ),
      ],
    ),
  ];

  void _agregarRutina(Rutina nuevaRutina) {
    setState(() {
      _rutinas.add(nuevaRutina);
      _currentIndex = 0;
    });
  }

  void _eliminarRutina(int index) {
    setState(() {
      _rutinas.removeAt(index);
    });
  }

  // NUEVA FUNCIÓN: Para guardar los cambios de una rutina editada
  void _editarRutina(int index, Rutina rutinaModificada) {
    setState(() {
      _rutinas[index] = rutinaModificada;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pantallas = [
      // Pasamos la nueva función onEditar a la pantalla de Inicio
      HomeScreen(
        rutinas: _rutinas,
        onEliminar: _eliminarRutina,
        onEditar: _editarRutina,
      ),
      FormularioScreen(onGuardarRutina: _agregarRutina),
      const PerfilScreen(),
    ];

    return Scaffold(
      body: pantallas[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Rutinas'),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Crear Rutina',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

// ==========================================
// PANTALLA 1: INICIO (LISTA DE RUTINAS)
// ==========================================
class HomeScreen extends StatelessWidget {
  final List<Rutina> rutinas;
  final Function(int) onEliminar;
  final Function(int, Rutina) onEditar; // Recibimos la función de editar

  const HomeScreen({
    super.key,
    required this.rutinas,
    required this.onEliminar,
    required this.onEditar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis Rutinas')),
      body: rutinas.isEmpty
          ? const Center(
              child: Text(
                'No hay rutinas creadas.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: rutinas.length,
              itemBuilder: (context, index) {
                final rutina = rutinas[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    leading: const Icon(
                      Icons.fitness_center,
                      color: Colors.blueAccent,
                    ),
                    title: Text(
                      rutina.nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Text('${rutina.ejercicios.length} ejercicios'),
                    children: [
                      ...rutina.ejercicios.map((ejercicio) {
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 32.0,
                          ),
                          title: Text(
                            ejercicio.nombre,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          subtitle: Text(
                            '${ejercicio.series} series x ${ejercicio.repeticiones} reps | Peso: ${ejercicio.peso} ${ejercicio.unidad}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        );
                      }),
                      // FILA DE BOTONES: Editar y Borrar
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              // Al presionar Editar, abrimos una nueva pantalla y le pasamos los datos
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditarRutinaScreen(
                                      rutina: rutina,
                                      index: index,
                                      onGuardarCambios: onEditar,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.blueAccent,
                                size: 20,
                              ),
                              label: const Text(
                                'Editar',
                                style: TextStyle(color: Colors.blueAccent),
                              ),
                            ),
                            const SizedBox(width: 16),
                            TextButton.icon(
                              onPressed: () => onEliminar(index),
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              label: const Text(
                                'Borrar',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ==========================================
// NUEVA PANTALLA: EDITAR RUTINA
// ==========================================
class EditarRutinaScreen extends StatefulWidget {
  final Rutina rutina;
  final int index;
  final Function(int, Rutina) onGuardarCambios;

  const EditarRutinaScreen({
    super.key,
    required this.rutina,
    required this.index,
    required this.onGuardarCambios,
  });

  @override
  State<EditarRutinaScreen> createState() => _EditarRutinaScreenState();
}

class _EditarRutinaScreenState extends State<EditarRutinaScreen> {
  final _formKey = GlobalKey<FormState>();

  late String _nombreRutina;
  late List<Ejercicio> _ejerciciosTemporales;

  final _nombreEjController = TextEditingController();
  final _seriesController = TextEditingController();
  final _repsController = TextEditingController();
  final _pesoController = TextEditingController();
  String _unidadSeleccionada = 'kg';

  @override
  void initState() {
    super.initState();
    // Al abrir la pantalla, cargamos los datos existentes
    _nombreRutina = widget.rutina.nombre;
    // Creamos una copia de los ejercicios para no modificar la original hasta que el usuario guarde
    _ejerciciosTemporales = List.from(widget.rutina.ejercicios);
  }

  void _agregarEjercicioTemporal() {
    if (_nombreEjController.text.isEmpty ||
        _seriesController.text.isEmpty ||
        _repsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Llena el nombre, series y reps del ejercicio'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _ejerciciosTemporales.add(
        Ejercicio(
          nombre: _nombreEjController.text,
          series: _seriesController.text,
          repeticiones: _repsController.text,
          peso: _pesoController.text.isEmpty ? '0' : _pesoController.text,
          unidad: _unidadSeleccionada,
        ),
      );
    });

    _nombreEjController.clear();
    _seriesController.clear();
    _repsController.clear();
    _pesoController.clear();
  }

  void _guardarCambios() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      if (_ejerciciosTemporales.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La rutina debe tener al menos un ejercicio'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Enviamos la rutina modificada y cerramos esta pantalla
      widget.onGuardarCambios(
        widget.index,
        Rutina(nombre: _nombreRutina, ejercicios: _ejerciciosTemporales),
      );
      Navigator.pop(context); // Regresa a la pantalla principal

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Cambios guardados!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar Rutina')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              initialValue: _nombreRutina, // Carga el nombre actual
              decoration: InputDecoration(
                labelText: 'Nombre de la Rutina',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
              ),
              validator: (value) => value == null || value.isEmpty
                  ? 'Dale un nombre a tu rutina'
                  : null,
              onSaved: (value) => _nombreRutina = value!,
            ),
            const Divider(height: 40, color: Colors.grey),

            const Text(
              'Agregar Nuevo Ejercicio',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nombreEjController,
              decoration: const InputDecoration(
                labelText: 'Nombre del ejercicio',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _seriesController,
                    decoration: const InputDecoration(
                      labelText: 'Series',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _repsController,
                    decoration: const InputDecoration(
                      labelText: 'Reps',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _pesoController,
                    decoration: const InputDecoration(
                      labelText: 'Peso (Opcional)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    value: _unidadSeleccionada,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: ['kg', 'lbs'].map((String valor) {
                      return DropdownMenuItem<String>(
                        value: valor,
                        child: Text(valor),
                      );
                    }).toList(),
                    onChanged: (nuevoValor) {
                      setState(() {
                        _unidadSeleccionada = nuevoValor!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _agregarEjercicioTemporal,
              icon: const Icon(Icons.add),
              label: const Text('Añadir a la lista'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(12),
              ),
            ),

            const SizedBox(height: 24),

            if (_ejerciciosTemporales.isNotEmpty) ...[
              const Text(
                'Ejercicios actuales en la rutina:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade800),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: _ejerciciosTemporales
                      .map(
                        (ej) => ListTile(
                          dense: true,
                          title: Text(ej.nombre),
                          subtitle: Text(
                            '${ej.series}x${ej.repeticiones} | ${ej.peso}${ej.unidad}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.redAccent,
                            ),
                            onPressed: () {
                              setState(() {
                                _ejerciciosTemporales.remove(ej);
                              });
                            }, // Borra el ejercicio de la lista
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],

            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _guardarCambios,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors
                    .green, // Color verde para indicar que estamos actualizando
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'GUARDAR CAMBIOS',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// PANTALLA 2: FORMULARIO (CREADOR DE RUTINAS NUEVAS)
// ==========================================
class FormularioScreen extends StatefulWidget {
  final Function(Rutina) onGuardarRutina;

  const FormularioScreen({super.key, required this.onGuardarRutina});

  @override
  State<FormularioScreen> createState() => _FormularioScreenState();
}

class _FormularioScreenState extends State<FormularioScreen> {
  final _formKey = GlobalKey<FormState>();
  String _nombreRutina = '';
  final List<Ejercicio> _ejerciciosTemporales = [];

  final _nombreEjController = TextEditingController();
  final _seriesController = TextEditingController();
  final _repsController = TextEditingController();
  final _pesoController = TextEditingController();
  String _unidadSeleccionada = 'kg';

  void _agregarEjercicioTemporal() {
    if (_nombreEjController.text.isEmpty ||
        _seriesController.text.isEmpty ||
        _repsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Llena el nombre, series y reps del ejercicio'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    setState(() {
      _ejerciciosTemporales.add(
        Ejercicio(
          nombre: _nombreEjController.text,
          series: _seriesController.text,
          repeticiones: _repsController.text,
          peso: _pesoController.text.isEmpty ? '0' : _pesoController.text,
          unidad: _unidadSeleccionada,
        ),
      );
    });
    _nombreEjController.clear();
    _seriesController.clear();
    _repsController.clear();
    _pesoController.clear();
  }

  void _guardarRutinaCompleta() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      if (_ejerciciosTemporales.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agrega al menos un ejercicio a la rutina'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      widget.onGuardarRutina(
        Rutina(
          nombre: _nombreRutina,
          ejercicios: List.from(_ejerciciosTemporales),
        ),
      );
      _ejerciciosTemporales.clear();
      _formKey.currentState!.reset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Rutina guardada exitosamente!'),
          backgroundColor: Colors.blueAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear Nueva Rutina')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Nombre de la Rutina',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
              ),
              validator: (value) => value == null || value.isEmpty
                  ? 'Dale un nombre a tu rutina'
                  : null,
              onSaved: (value) => _nombreRutina = value!,
            ),
            const Divider(height: 40, color: Colors.grey),
            const Text(
              'Agregar Ejercicio',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nombreEjController,
              decoration: const InputDecoration(
                labelText: 'Nombre del ejercicio',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _seriesController,
                    decoration: const InputDecoration(
                      labelText: 'Series',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _repsController,
                    decoration: const InputDecoration(
                      labelText: 'Reps',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _pesoController,
                    decoration: const InputDecoration(
                      labelText: 'Peso (Opcional)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    value: _unidadSeleccionada,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: ['kg', 'lbs'].map((String valor) {
                      return DropdownMenuItem<String>(
                        value: valor,
                        child: Text(valor),
                      );
                    }).toList(),
                    onChanged: (nuevoValor) {
                      setState(() {
                        _unidadSeleccionada = nuevoValor!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _agregarEjercicioTemporal,
              icon: const Icon(Icons.add),
              label: const Text('Añadir a la lista'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 24),
            if (_ejerciciosTemporales.isNotEmpty) ...[
              const Text(
                'Ejercicios en esta rutina:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade800),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: _ejerciciosTemporales
                      .map(
                        (ej) => ListTile(
                          dense: true,
                          title: Text(ej.nombre),
                          subtitle: Text(
                            '${ej.series}x${ej.repeticiones} | ${ej.peso}${ej.unidad}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.redAccent,
                            ),
                            onPressed: () {
                              setState(() {
                                _ejerciciosTemporales.remove(ej);
                              });
                            },
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _guardarRutinaCompleta,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'GUARDAR RUTINA COMPLETA',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// PANTALLA 3: PERFIL
// ==========================================
class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blueAccent, width: 3),
              ),
              child: const CircleAvatar(
                radius: 50,
                backgroundColor: Colors.transparent,
                child: Icon(Icons.person, size: 50, color: Colors.blueAccent),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Adrian Acosta',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Nivel: Pro', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
