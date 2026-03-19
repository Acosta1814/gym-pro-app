import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// Llave global para poder mostrar SnackBars desde cualquier parte de la app (como el temporizador)
final GlobalKey<ScaffoldMessengerState> snackbarKey =
    GlobalKey<ScaffoldMessengerState>();

void main() {
  runApp(const GymApp());
}

// ==========================================
// SERVICIO DE TEMPORIZADOR GLOBAL
// ==========================================
class TimerService {
  static final TimerService _instance = TimerService._internal();
  factory TimerService() => _instance;
  TimerService._internal();

  ValueNotifier<int> tiempoRestante = ValueNotifier<int>(0);
  Timer? _timer;

  Future<void> iniciarDescanso([int segundos = 180]) async {
    _timer?.cancel();
    tiempoRestante.value = segundos;

    final prefs = await SharedPreferences.getInstance();
    final endTime = DateTime.now().millisecondsSinceEpoch + (segundos * 1000);
    await prefs.setInt('timer_end', endTime);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (tiempoRestante.value > 0) {
        tiempoRestante.value--;
      } else {
        cancelarDescanso(notificar: true);
      }
    });
  }

  Future<void> cancelarDescanso({bool notificar = false}) async {
    _timer?.cancel();
    tiempoRestante.value = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('timer_end');

    if (notificar) {
      snackbarKey.currentState?.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.notifications_active, color: Colors.white),
              SizedBox(width: 10),
              Text(
                '¡Tiempo de descanso finalizado!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> restaurarTimer() async {
    final prefs = await SharedPreferences.getInstance();
    final endTime = prefs.getInt('timer_end');
    if (endTime != null) {
      final tiempoRestanteReal =
          (endTime - DateTime.now().millisecondsSinceEpoch) ~/ 1000;
      if (tiempoRestanteReal > 0) {
        iniciarDescanso(tiempoRestanteReal);
      } else {
        await prefs.remove('timer_end');
      }
    }
  }
}

final timerService = TimerService();

// ==========================================
// MODELOS DE DATOS (Con Modo Tiempo Integrado)
// ==========================================
class Ejercicio {
  String nombre, series, repeticiones, peso, unidad, tiempo;
  bool esTiempo; // Determina si es isométrico (segundos) o hipertrofia (reps)

  Ejercicio({
    required this.nombre,
    required this.series,
    required this.repeticiones,
    required this.peso,
    required this.unidad,
    this.tiempo = '0',
    this.esTiempo = false,
  });

  Map<String, dynamic> toMap() => {
    'nombre': nombre,
    'series': series,
    'repeticiones': repeticiones,
    'peso': peso,
    'unidad': unidad,
    'tiempo': tiempo,
    'esTiempo': esTiempo,
  };

  factory Ejercicio.fromMap(Map<String, dynamic> map) => Ejercicio(
    nombre: map['nombre'] ?? '',
    series: map['series'] ?? '0',
    repeticiones: map['repeticiones'] ?? '0',
    peso: map['peso']?.toString() ?? '0',
    unidad: map['unidad'] ?? 'kg',
    tiempo: map['tiempo']?.toString() ?? '0', // Fallback para rutinas viejas
    esTiempo: map['esTiempo'] ?? false,
  );
}

class Rutina {
  String nombre;
  List<Ejercicio> ejercicios;
  Rutina({required this.nombre, required this.ejercicios});
  Map<String, dynamic> toMap() => {
    'nombre': nombre,
    'ejercicios': ejercicios.map((e) => e.toMap()).toList(),
  };
  factory Rutina.fromMap(Map<String, dynamic> map) => Rutina(
    nombre: map['nombre'] ?? '',
    ejercicios: (map['ejercicios'] as List)
        .map((e) => Ejercicio.fromMap(e))
        .toList(),
  );
}

class Record1RM {
  String ejercicio;
  double pesoMaximo;
  String fecha;
  Record1RM({
    required this.ejercicio,
    required this.pesoMaximo,
    required this.fecha,
  });
  Map<String, dynamic> toMap() => {
    'ejercicio': ejercicio,
    'pesoMaximo': pesoMaximo,
    'fecha': fecha,
  };
  factory Record1RM.fromMap(Map<String, dynamic> map) => Record1RM(
    ejercicio: map['ejercicio'],
    pesoMaximo: map['pesoMaximo'],
    fecha: map['fecha'],
  );
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
      title: 'Gym Pro App',
      scaffoldMessengerKey: snackbarKey,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        colorScheme: const ColorScheme.dark(
          primary: Colors.redAccent,
          surface: Color(0xFF1C1C1E),
          onSurface: Colors.white,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D0D0D),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 1,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF121212),
          selectedItemColor: Colors.redAccent,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
        ),
      ),
      home: const AuthCheckScreen(),
    );
  }
}

// ==========================================
// CONTROL DE SESIÓN
// ==========================================
class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});
  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  @override
  void initState() {
    super.initState();
    timerService.restaurarTimer();
    _revisarSesion();
  }

  Future<void> _revisarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    final String? usuario = prefs.getString('usuario_actual');
    await Future.delayed(const Duration(milliseconds: 500));

    if (usuario != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigator()),
      );
    } else if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: Colors.redAccent)),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();

  Future<void> _iniciarSesion() async {
    if (_userController.text.isNotEmpty && _passController.text.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('usuario_actual', _userController.text);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigator()),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa tus credenciales'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.fitness_center,
                size: 90,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 20),
              const Text(
                'GYM PRO',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _userController,
                decoration: InputDecoration(
                  labelText: 'Usuario',
                  prefixIcon: const Icon(Icons.person, color: Colors.redAccent),
                  filled: true,
                  fillColor: const Color(0xFF1C1C1E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock, color: Colors.redAccent),
                  filled: true,
                  fillColor: const Color(0xFF1C1C1E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: _iniciarSesion,
                child: const Text(
                  'INICIAR SESIÓN',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// NAVEGADOR PRINCIPAL
// ==========================================
class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});
  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _currentIndex = 0;
  List<Rutina> _rutinas = [];
  final String apiUrl = "http://192.168.0.217:8080/rutinas";

  @override
  void initState() {
    super.initState();
    _sincronizarDatos();
  }

  Future<void> _sincronizarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final response = await http
          .get(Uri.parse(apiUrl))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        List<dynamic> decodedData = jsonDecode(response.body);
        setState(
          () => _rutinas = decodedData
              .map((item) => Rutina.fromMap(item))
              .toList(),
        );
        return;
      }
    } catch (e) {
      debugPrint("Usando datos locales");
    }
    String? localData = prefs.getString('rutinas_adrian');
    if (localData != null) {
      setState(
        () => _rutinas = (jsonDecode(localData) as List)
            .map((item) => Rutina.fromMap(item))
            .toList(),
      );
    }
  }

  Future<void> _guardarYEnviar() async {
    final prefs = await SharedPreferences.getInstance();
    String encodedData = jsonEncode(_rutinas.map((r) => r.toMap()).toList());
    await prefs.setString('rutinas_adrian', encodedData);
    try {
      await http
          .post(
            Uri.parse(apiUrl),
            headers: {"Content-Type": "application/json"},
            body: encodedData,
          )
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint("Error guardando: $e");
    }
  }

  void _agregarRutina(Rutina nueva) {
    setState(() {
      _rutinas.add(nueva);
      _currentIndex = 0;
    });
    _guardarYEnviar();
  }

  void _eliminarRutina(int index) {
    setState(() => _rutinas.removeAt(index));
    _guardarYEnviar();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pantallas = [
      HomeScreen(rutinas: _rutinas, onEliminar: _eliminarRutina),
      FormularioScreen(onGuardarRutina: _agregarRutina),
      const ProgresoScreen(),
      const PerfilScreen(),
    ];

    return Scaffold(
      body: pantallas[_currentIndex],
      floatingActionButton: ValueListenableBuilder<int>(
        valueListenable: timerService.tiempoRestante,
        builder: (context, tiempo, child) {
          if (tiempo == 0) return const SizedBox.shrink();

          final minutos = (tiempo ~/ 60).toString().padLeft(2, '0');
          final segundos = (tiempo % 60).toString().padLeft(2, '0');

          return FloatingActionButton.extended(
            onPressed: () => timerService.cancelarDescanso(),
            backgroundColor: Colors.white,
            icon: const Icon(Icons.timer_off, color: Colors.redAccent),
            label: Text(
              '$minutos:$segundos',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.redAccent,
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Entrenar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Nueva Rutina',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insert_chart_outlined),
            label: 'Progreso',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

// ==========================================
// PANTALLA 1: ENTRENAR (CON MÉTRICAS INTELIGENTES)
// ==========================================
class HomeScreen extends StatelessWidget {
  final List<Rutina> rutinas;
  final Function(int) onEliminar;
  const HomeScreen({
    super.key,
    required this.rutinas,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrenamiento'),
        actions: [
          IconButton(
            icon: const Icon(Icons.timer, color: Colors.redAccent),
            tooltip: 'Descanso Rápido',
            onPressed: () => timerService.iniciarDescanso(180),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.redAccent, Colors.deepOrangeAccent],
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  minimumSize: const Size(double.infinity, 60),
                ),
                icon: const Icon(
                  Icons.play_arrow,
                  size: 28,
                  color: Colors.white,
                ),
                label: const Text(
                  'INICIAR ENTRENAMIENTO VACÍO',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                onPressed: () {},
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Mis Rutinas Guardadas',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: rutinas.isEmpty
                ? const Center(
                    child: Text(
                      'Aún no tienes rutinas.\n¡Crea una en la pestaña "+ Nueva Rutina"!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(
                      bottom: 80,
                      left: 16,
                      right: 16,
                    ),
                    itemCount: rutinas.length,
                    itemBuilder: (context, index) {
                      final rutina = rutinas[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: ExpansionTile(
                          shape: const RoundedRectangleBorder(
                            side: BorderSide.none,
                          ),
                          iconColor: Colors.redAccent,
                          collapsedIconColor: Colors.grey,
                          title: Text(
                            rutina.nombre,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            '${rutina.ejercicios.length} ejercicios',
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                          children: [
                            const Divider(color: Colors.white10),
                            ...rutina.ejercicios.map(
                              (ej) => ListTile(
                                // Ícono dinámico
                                leading: Icon(
                                  ej.esTiempo
                                      ? Icons.timer
                                      : Icons.accessibility_new,
                                  color: Colors.grey,
                                ),
                                title: Text(
                                  ej.nombre,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                // Renderizado inteligente (Reps vs Segundos)
                                subtitle: Text(
                                  ej.esTiempo
                                      ? '${ej.series} series x ${ej.tiempo}s'
                                      : '${ej.series} series x ${ej.repeticiones} reps',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                // Renderizado de Peso (Muestra Corporal si es 0)
                                trailing: Text(
                                  ej.peso == '0' || ej.peso.isEmpty
                                      ? 'Corporal'
                                      : '${ej.peso} ${ej.unidad}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextButton.icon(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                                label: const Text(
                                  'Eliminar Rutina',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                                onPressed: () => onEliminar(index),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// PANTALLA 2: NUEVA RUTINA (SWITCH DE TIEMPO)
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
  List<String> _todosLosEjercicios = [];
  bool _cargandoEjercicios = true;
  String _ejercicioBuscado = '';

  // Variables para el modo Isométrico
  bool _modoTiempo = false;
  final _tiempoController = TextEditingController();

  final _seriesController = TextEditingController();
  final _repsController = TextEditingController();
  final _pesoController = TextEditingController();
  String _unidadSeleccionada = 'kg';

  @override
  void initState() {
    super.initState();
    _obtenerEjerciciosDeAPI();
  }

  // MEGA DICCIONARIO
  String _traducirEjercicio(String nombreIngles) {
    String nombre = nombreIngles.toLowerCase();

    final traducciones = {
      'romanian deadlift': 'Peso Muerto Rumano',
      'bulgarian split squat': 'Sentadilla Búlgara',
      'lat pulldown': 'Jalón al Pecho',
      'bench press': 'Press de Banca',
      'push up': 'Flexión',
      'push-up': 'Flexión',
      'pull up': 'Dominada',
      'pull-up': 'Dominada',
      'chin up': 'Dominada Supina',
      'chin-up': 'Dominada Supina',
      'leg press': 'Prensa de Piernas',
      'leg extension': 'Extensión de Piernas',
      'leg curl': 'Curl de Piernas',
      'calf raise': 'Elevación de Pantorrillas',
      'shoulder press': 'Press de Hombros',
      'military press': 'Press Militar',
      'bicep curl': 'Curl de Bíceps',
      'tricep extension': 'Extensión de Tríceps',
      'tricep pushdown': 'Extensión de Tríceps en Polea',
      'skull crusher': 'Rompecráneos',
      'front raise': 'Elevación Frontal',
      'lateral raise': 'Elevación Lateral',
      'hip thrust': 'Hip Thrust',
      'glute bridge': 'Puente de Glúteos',
      'russian twist': 'Giro Ruso',
      'jumping jack': 'Jumping Jack',
      'mountain climber': 'Mountain Climber',
      'close grip': 'Agarre Estrecho',
      'wide grip': 'Agarre Amplio',
      'reverse grip': 'Agarre Invertido',
      'neutral grip': 'Agarre Neutro',
      'underhand': 'Supino',
      'overhand': 'Prono',
      'single arm': 'a una Mano',
      'single leg': 'a una Pierna',
      'one arm': 'a una Mano',
      'alternating': 'Alterno',
      'seated': 'Sentado',
      'standing': 'de Pie',
      'lying': 'Acostado',
      'incline': 'Inclinado',
      'decline': 'Declinado',
      'bent over': 'Inclinado',
      'kneeling': 'de Rodillas',
      'barbell': 'con Barra',
      'dumbbell': 'con Mancuerna',
      'kettlebell': 'con Pesa Rusa',
      'cable': 'en Polea',
      'machine': 'en Máquina',
      'smith machine': 'en Máquina Smith',
      'ez bar': 'con Barra EZ',
      'ez-bar': 'con Barra EZ',
      'band': 'con Banda',
      'medicine ball': 'con Balón Medicinal',
      'bodyweight': 'con Peso Corporal',
      'rope': 'con Cuerda',
      'v-bar': 'con Barra en V',
      'deadlift': 'Peso Muerto',
      'squat': 'Sentadilla',
      'lunge': 'Zancada',
      'curl': 'Curl',
      'extension': 'Extensión',
      'fly': 'Apertura',
      'row': 'Remo',
      'press': 'Press',
      'crunch': 'Crunch',
      'plank': 'Plancha',
      'dip': 'Fondo',
      'raise': 'Elevación',
      'shrug': 'Encogimiento',
      'kickback': 'Patada Trasera',
      'pullover': 'Pullover',
      'swing': 'Swing',
      'chest': 'de Pecho',
      'back': 'de Espalda',
      'shoulder': 'de Hombros',
      'leg': 'de Piernas',
      'bicep': 'de Bíceps',
      'tricep': 'de Tríceps',
      'calf': 'de Pantorrillas',
      'glute': 'de Glúteos',
      'hamstring': 'Isquiosural',
      'quad': 'Cuádriceps',
      'ab': 'Abdominal',
      'core': 'Core',
    };

    traducciones.forEach((ing, esp) {
      nombre = nombre.replaceAll(
        RegExp('\\b$ing\\b', caseSensitive: false),
        esp,
      );
    });

    nombre = nombre.replaceAll('  ', ' ').trim();

    if (nombre.isNotEmpty) {
      nombre = nombre
          .split(' ')
          .map((str) {
            if (['de', 'con', 'en', 'a', 'al'].contains(str.toLowerCase()))
              return str.toLowerCase();
            if (str.length > 1)
              return str[0].toUpperCase() + str.substring(1).toLowerCase();
            return str.toUpperCase();
          })
          .join(' ');

      nombre = nombre[0].toUpperCase() + nombre.substring(1);
    }
    return nombre;
  }

  Future<void> _obtenerEjerciciosDeAPI() async {
    final url = Uri.parse(
      'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json',
    );
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List resultados = jsonDecode(response.body);
        Set<String> nombresUnicos = {};

        for (var item in resultados) {
          if (item['name'] != null) {
            String nombreIngles = item['name'].toString().trim();
            if (nombreIngles.isNotEmpty) {
              nombresUnicos.add(_traducirEjercicio(nombreIngles));
            }
          }
        }
        if (nombresUnicos.isNotEmpty && mounted) {
          setState(() {
            _todosLosEjercicios = nombresUnicos.toList()..sort();
            _cargandoEjercicios = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Error API: $e');
    }
    _cargarCatalogoPorDefecto();
  }

  void _cargarCatalogoPorDefecto() {
    if (!mounted) return;
    setState(() {
      _todosLosEjercicios = [
        'Press de Banca',
        'Sentadilla con Barra',
        'Peso Muerto',
        'Dominada',
        'Flexión',
        'Press Militar',
      ]..sort();
      _cargandoEjercicios = false;
    });
  }

  void _agregarEjercicioTemporal() {
    if (_ejercicioBuscado.isEmpty || _seriesController.text.isEmpty) return;

    // Validación dependiente del modo
    if (!_modoTiempo && _repsController.text.isEmpty) return;
    if (_modoTiempo && _tiempoController.text.isEmpty) return;

    setState(() {
      _ejerciciosTemporales.add(
        Ejercicio(
          nombre: _ejercicioBuscado,
          series: _seriesController.text,
          repeticiones: _modoTiempo ? '0' : _repsController.text,
          tiempo: _modoTiempo ? _tiempoController.text : '0',
          esTiempo: _modoTiempo,
          peso: _pesoController.text.isEmpty ? '0' : _pesoController.text,
          unidad: _unidadSeleccionada,
        ),
      );
    });
    _ejercicioBuscado = '';
    _seriesController.clear();
    _repsController.clear();
    _tiempoController.clear();
    _pesoController.clear();
    FocusScope.of(context).unfocus();
  }

  void _guardarRutinaCompleta() {
    if (_formKey.currentState!.validate() && _ejerciciosTemporales.isNotEmpty) {
      _formKey.currentState!.save();
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
          content: Text('¡Rutina guardada!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoEjercicios)
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.redAccent)),
      );

    return Scaffold(
      appBar: AppBar(title: const Text('Creador de Rutinas')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Nombre de la Rutina: Ej. "Día de Pecho y Tríceps"',
                filled: true,
                fillColor: const Color(0xFF1C1C1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
              onSaved: (v) => _nombreRutina = v!,
              validator: (v) =>
                  v!.isEmpty ? 'Ponle un nombre a tu rutina' : null,
            ),
            const SizedBox(height: 24),
            const Text(
              'Agregar Ejercicio',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Autocomplete<String>(
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text == '')
                  return const Iterable<String>.empty();
                return _todosLosEjercicios.where(
                  (opt) => opt.toLowerCase().contains(
                    textEditingValue.text.toLowerCase(),
                  ),
                );
              },
              onSelected: (selection) => _ejercicioBuscado = selection,
              fieldViewBuilder:
                  (context, controller, focusNode, onEditingComplete) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Buscar Ejercicio...',
                        filled: true,
                        fillColor: const Color(0xFF1C1C1E),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.redAccent,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (text) => _ejercicioBuscado = text,
                    );
                  },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 10,
                    borderRadius: BorderRadius.circular(15),
                    color: const Color(0xFF2C2C2E),
                    child: SizedBox(
                      height: 250,
                      width: MediaQuery.of(context).size.width - 32,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final option = options.elementAt(index);
                          return ListTile(
                            leading: const Icon(
                              Icons.fitness_center,
                              color: Colors.grey,
                              size: 20,
                            ),
                            title: Text(
                              option,
                              style: const TextStyle(color: Colors.white),
                            ),
                            onTap: () {
                              onSelected(option);
                              FocusScope.of(context).unfocus();
                            },
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // SWITCH PARA CAMBIAR ENTRE REPS Y TIEMPO
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                '¿Medir por Tiempo?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Actívalo para planchas, isométricos o L-sits',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              value: _modoTiempo,
              activeColor: Colors.redAccent,
              onChanged: (val) {
                setState(() {
                  _modoTiempo = val;
                });
              },
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _seriesController,
                    decoration: _inputStyle('Series', Icons.repeat),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                // Muestra Reps o Segundos dependiendo del Switch
                if (!_modoTiempo)
                  Expanded(
                    child: TextFormField(
                      controller: _repsController,
                      decoration: _inputStyle('Reps', Icons.tag),
                      keyboardType: TextInputType.number,
                    ),
                  )
                else
                  Expanded(
                    child: TextFormField(
                      controller: _tiempoController,
                      decoration: _inputStyle('Segundos', Icons.timer),
                      keyboardType: TextInputType.number,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _pesoController,
                    decoration: _inputStyle(
                      _modoTiempo
                          ? 'Lastre (0 = Corporal)'
                          : 'Peso (0 = Corporal)',
                      Icons.scale,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    value: _unidadSeleccionada,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF1C1C1E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: ['kg', 'lbs']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _unidadSeleccionada = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C2C2E),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              icon: const Icon(Icons.add, color: Colors.redAccent),
              label: const Text(
                'AÑADIR A LA LISTA',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: _agregarEjercicioTemporal,
            ),
            if (_ejerciciosTemporales.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Divider(color: Colors.white24),
              ..._ejerciciosTemporales.map(
                (ej) => Card(
                  color: const Color(0xFF1C1C1E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    title: Text(
                      ej.nombre,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      ej.esTiempo
                          ? '${ej.series} series x ${ej.tiempo}s | Lastre: ${ej.peso}${ej.unidad}'
                          : '${ej.series} series x ${ej.repeticiones} reps | Peso: ${ej.peso}${ej.unidad}',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () =>
                          setState(() => _ejerciciosTemporales.remove(ej)),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: _guardarRutinaCompleta,
              child: const Text(
                'GUARDAR RUTINA',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey, size: 20),
      filled: true,
      fillColor: const Color(0xFF1C1C1E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
    );
  }
}

// ==========================================
// PANTALLA 3: PROGRESO (1RM)
// ==========================================
class ProgresoScreen extends StatefulWidget {
  const ProgresoScreen({super.key});
  @override
  State<ProgresoScreen> createState() => _ProgresoScreenState();
}

class _ProgresoScreenState extends State<ProgresoScreen> {
  final _pesoCalcController = TextEditingController();
  final _repsCalcController = TextEditingController();
  double? _resultado1RM;

  void _calcular1RM() {
    if (_pesoCalcController.text.isNotEmpty &&
        _repsCalcController.text.isNotEmpty) {
      setState(() {
        double p = double.parse(_pesoCalcController.text);
        int r = int.parse(_repsCalcController.text);
        _resultado1RM = p * (1 + (r / 30));
      });
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calculadora 1RM')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.electric_bolt,
                    size: 40,
                    color: Colors.yellowAccent,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Descubre tu fuerza máxima',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _pesoCalcController,
                          decoration: InputDecoration(
                            labelText: 'Peso levantado (kg)',
                            filled: true,
                            fillColor: const Color(0xFF2C2C2E),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _repsCalcController,
                          decoration: InputDecoration(
                            labelText: 'Repeticiones',
                            filled: true,
                            fillColor: const Color(0xFF2C2C2E),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: _calcular1RM,
                    child: const Text(
                      'CALCULAR',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_resultado1RM != null) ...[
              const SizedBox(height: 30),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.redAccent, Colors.deepOrange],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.4),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'TU REPETICIÓN MÁXIMA',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${_resultado1RM!.toStringAsFixed(1)} kg',
                      style: const TextStyle(
                        fontSize: 50,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==========================================
// PANTALLA 4: PERFIL
// ==========================================
class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});
  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  String _nombreUsuario = "Atleta";

  @override
  void initState() {
    super.initState();
    _cargarUsuario();
  }

  Future<void> _cargarUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    setState(
      () => _nombreUsuario = prefs.getString('usuario_actual') ?? "Atleta",
    );
  }

  Future<void> _cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('usuario_actual');
    if (mounted)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.redAccent, Colors.orange],
                ),
              ),
              child: const CircleAvatar(
                radius: 60,
                backgroundColor: Color(0xFF1C1C1E),
                child: Icon(Icons.person, size: 60, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _nombreUsuario.toUpperCase(),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const Text(
              'Nivel: Pro',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label: const Text('Cerrar Sesión'),
              onPressed: _cerrarSesion,
            ),
          ],
        ),
      ),
    );
  }
}
