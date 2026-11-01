import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const WorkoutApp());
}

// ---------------------------------------------------------------------------
// 1. Модель данных Exercise
// ---------------------------------------------------------------------------
class Exercise {
  final String? id;
  final String name;
  final String muscleGroup;
  final String? description;
  final String? linkVideo;
  final bool isGeneral;

  Exercise({
    this.id,
    required this.name,
    required this.muscleGroup,
    this.description,
    this.linkVideo,
    this.isGeneral = false,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id']?.toString(),
      name: json['name'],
      muscleGroup: json['muscleGroup'],
      description: json['description'],
      linkVideo: json['linkVideo'],
      isGeneral: json['owner'] == null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'muscleGroup': muscleGroup,
      'description': description,
      'linkVideo': linkVideo,
    };
  }
}

// ---------------------------------------------------------------------------
// 2. Сервис для работы с API (Упражнения + Авторизация/Регистрация)
// ---------------------------------------------------------------------------
class ApiService {
  static const String baseUrl = 'http://10.0.2.2:8080';


  final http.Client _client = http.Client();

  // Переменная для хранения куки сессии
  String? _sessionCookie;

  // Вспомогательный метод для добавления куки в заголовки
  Map<String, String> _getHeaders({bool isJson = false}) {
    final headers = <String, String>{};
    if (isJson) {
      headers['Content-Type'] = 'application/json; charset=UTF-8';
    }
    if (_sessionCookie != null) {
      headers['cookie'] = _sessionCookie!;
    }
    return headers;
  }

  // --- Упражнения ---

  Future<List<Exercise>> getExercises() async {
    final response = await _client.get(Uri.parse('$baseUrl/exercises/all'), headers: _getHeaders());

    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((dynamic item) => Exercise.fromJson(item)).toList();
    } else {
      throw Exception('Ошибка загрузки: ${response.statusCode}');
    }
  }

  Future<bool> addExercise(Exercise exercise) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/exercises/create'),
      headers: _getHeaders(isJson: true),
      body: utf8.encode(jsonEncode(exercise.toJson())),
    );

    return response.statusCode == 200 || response.statusCode == 201;
  }

  Future<bool> updateExercise(String id, Exercise exercise) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/exercises/update/$id'),
      headers: _getHeaders(isJson: true),
      body: utf8.encode(jsonEncode(exercise.toJson())),
    );

    return response.statusCode == 200 || response.statusCode == 201;
  }

  Future<bool> deleteExercise(String id) async {
    final response = await _client.delete(
      Uri.parse('$baseUrl/exercises/delete/$id'),
        headers: _getHeaders()
    );

    return response.statusCode == 200 || response.statusCode == 204;
  }

  // --- Авторизация и Регистрация ---

  // Регистрация нового пользователя
  Future<bool> register(String username, String password, int yearOfBirth) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/registration'),
      headers: _getHeaders(isJson: true),
      body: jsonEncode({
        'username': username,
        'password': password,
        'yearOfBirth': yearOfBirth,
      }),
    );

    return response.statusCode == 200;
  }

  // Вход (отправляем данные на форму Spring Security /process_login)
  Future<bool> login(String username, String password) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/process_login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'username': username,
          'password': password,
        },
      );
      if (response.statusCode == 302 || response.statusCode == 200) {
        // Сохраняем куку сессии (JSESSIONID) из ответа бэкенда
        final rawCookie = response.headers['set-cookie'];
        if (rawCookie != null) {
          _sessionCookie = rawCookie.split(';').first;
        }

        final redirectUrl = response.headers['location'] ?? '';
        if (redirectUrl.contains('error')) {
          return false;
        }
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }
}
// ---------------------------------------------------------------------------
// Главный экран приложения с нижней панелью навигации (в серых тонах)
// ---------------------------------------------------------------------------
class MainScreen extends StatefulWidget {
  final ApiService apiService; // Предполагается, что у вас есть ваш ApiService

  const MainScreen({super.key, required this.apiService});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // -1 = главный экран (ни одна вкладка не выбрана)
  int _currentIndex = -1;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      ExercisesScreen(apiService: widget.apiService), // План
      const NutritionTabPlaceholder(),                // Питание
      const StatisticsTabPlaceholder(),               // Статистика
      const HistoryTabPlaceholder(),                  // История
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bool onHome = _currentIndex < 0;

    return PopScope(
      // Пока мы не на главном экране, "назад" возвращает на главный, а не закрывает приложение
      canPop: onHome,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) setState(() => _currentIndex = -1);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A18),
        body: onHome
            ? HomeDashboardTab(apiService: widget.apiService)
            : _screens[_currentIndex],
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: const Color(0xFF0A0A18),
            indicatorColor: onHome ? Colors.transparent : const Color(0xFF3A3768),
            indicatorShape: const StadiumBorder(),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected) && !onHome) {
                return const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12);
              }
              return TextStyle(color: Colors.grey.shade400, fontSize: 12);
            }),
          ),
          child: NavigationBar(
            // NavigationBar не умеет "ничего не выбрано", поэтому на главной
            // ставим 0, но визуально делаем его невыбранным (см. выше и ниже)
            selectedIndex: onHome ? 0 : _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.assignment_outlined, color: Colors.grey),
                selectedIcon: Icon(
                  onHome ? Icons.assignment_outlined : Icons.assignment,
                  color: onHome ? Colors.grey : Colors.white,
                ),
                label: 'План',
              ),
              const NavigationDestination(
                icon: Icon(Icons.restaurant_outlined, color: Colors.grey),
                selectedIcon: Icon(Icons.restaurant, color: Colors.white),
                label: 'Питание',
              ),
              const NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined, color: Colors.grey),
                selectedIcon: Icon(Icons.bar_chart, color: Colors.white),
                label: 'Статистика',
              ),
              const NavigationDestination(
                icon: Icon(Icons.history_outlined, color: Colors.grey),
                selectedIcon: Icon(Icons.history, color: Colors.white),
                label: 'История',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Вкладка "План тренировок" (Главная панель с карточкой из макета)
// ---------------------------------------------------------------------------
class HomeDashboardTab extends StatelessWidget {
  final ApiService apiService;

  const HomeDashboardTab({super.key, required this.apiService});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Фон с лёгким градиентом
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0D0D26), Color(0xFF07070F)],
              ),
            ),
          ),
        ),

        // Геометрическая сетка внизу (плавно проявляется снизу вверх)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 320,
          child: ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.white],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: CustomPaint(painter: _GridPainter(), size: Size.infinite),
          ),
        ),

        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 12),

                // Логотип
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.directions_run, color: Colors.white, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      'SPORTIK',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),

                const Spacer(flex: 2),

                // Свечение + картинка
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF4B3FBF).withValues(alpha: 0.55),
                            const Color(0xFF4B3FBF).withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                    Image.asset(
                      'assets/images/back_muscles.png',
                      width: 200,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.accessibility_new_rounded,
                        size: 130,
                        color: Color(0xFFC8826B),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Тексты
                const Text(
                  'Добрый день, Игорь!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Сегодня у вас по плану\nтренировка спины',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, color: Colors.white, height: 1.35),
                ),
                const SizedBox(height: 12),
                Text(
                  'Будь сильнее вчерашнего дня!',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),

                const Spacer(flex: 3),

                // Кнопка
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4A4D58), Color(0xFF8A8E99), Color(0xFF4A4D58)],
                    ),
                    border: Border.all(
                      color: const Color(0xFF5B6BC0).withValues(alpha: 0.8),
                      width: 1.5,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WorkoutComingSoonScreen(),
                          ),
                        );
                      },
                      child: const Center(
                        child: Text(
                          'Начать тренировку',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class WorkoutComingSoonScreen extends StatelessWidget {
  const WorkoutComingSoonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A18),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('Тренировка'),
      ),
      body: const Center(
        child: Text(
          'Скоро будет',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3B3F6B).withValues(alpha: 0.3)
      ..strokeWidth = 1;

    const step = 60.0;

    // Вертикальные линии
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // Диагонали
    for (double x = -size.height; x <= size.width; x += step * 1.5) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Заглушки для остальных вкладок
// ---------------------------------------------------------------------------
class NutritionTabPlaceholder extends StatelessWidget {
  const NutritionTabPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Раздел: Питание', style: TextStyle(color: Colors.grey, fontSize: 18)),
    );
  }
}

class StatisticsTabPlaceholderInfo extends StatelessWidget {
  const StatisticsTabPlaceholderInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Раздел: Статистика', style: TextStyle(color: Colors.grey, fontSize: 18)),
    );
  }
}

// (Можете заменить эти заглушки на ваши существующие экраны упражнений или статистики)
class StatisticsTabPlaceholder extends StatelessWidget {
  const StatisticsTabPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Раздел: Статистика', style: TextStyle(color: Colors.grey, fontSize: 18)),
    );
  }
}

class HistoryTabPlaceholder extends StatelessWidget {
  const HistoryTabPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Раздел: История тренировок', style: TextStyle(color: Colors.grey, fontSize: 18)),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Виджет Видеоплеера
// ---------------------------------------------------------------------------
class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerWidget({super.key, required this.videoUrl});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    final videoId = YoutubePlayerController.convertUrlToId(widget.videoUrl);

    if (videoId != null && videoId.isNotEmpty) {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: false,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Некорректная ссылка на видео: ${widget.videoUrl}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: YoutubePlayer(
        controller: _controller!,
        aspectRatio: 16 / 9,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Экран Авторизации (Login)
// ---------------------------------------------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final ApiService _apiService = ApiService();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _login() async {
    setState(() => _isLoading = true);
    bool success = await _apiService.login(
      _usernameController.text.trim(),
      _passwordController.text.trim(),
    );
    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainScreen(apiService: _apiService)),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка входа: неверный логин или пароль')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Вход в Workout App')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.fitness_center, size: 80, color: Colors.deepPurple),
                const SizedBox(height: 24),
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Имя пользователя (Логин)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Пароль'),
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  child: const Text('Войти'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RegisterScreen()),
                    );
                  },
                  child: const Text('Нет аккаунта? Зарегистрироваться'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Экран Регистрации (Register)
// ---------------------------------------------------------------------------
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final ApiService _apiService = ApiService();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _yearController = TextEditingController();
  bool _isLoading = false;

  void _register() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final year = int.tryParse(_yearController.text.trim()) ?? 2000;

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля')),
      );
      return;
    }

    setState(() => _isLoading = true);
    bool success = await _apiService.register(username, password, year);
    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Регистрация успешна! Войдите в систему.')),
      );
      Navigator.pop(context); // Возврат на экран входа
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка регистрации (возможно, логин занят)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Имя пользователя'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Пароль'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _yearController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Год рождения'),
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: _register,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  child: const Text('Зарегистрироваться'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 6. Главный интерфейс приложения (WorkoutApp & ExercisesScreen)
// ---------------------------------------------------------------------------
class WorkoutApp extends StatelessWidget {
  const WorkoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Workout App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // Устанавливаем экран авторизации стартовым
      home: const LoginScreen(),
    );
  }
}

class ExercisesScreen extends StatefulWidget {
  final ApiService apiService;

  const ExercisesScreen({super.key, required this.apiService});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  late Future<List<Exercise>> _exercisesFuture;

  // Выбранная категория фильтра. По умолчанию "Все"
  String _selectedCategory = 'Все';

  @override
  void initState() {
    super.initState();
    _refreshExercises();
  }

  void _refreshExercises() {
    setState(() {
      _exercisesFuture = widget.apiService.getExercises();
    });
  }

  // Модальное окно для добавления / редактирования
  void _showExerciseDialog({Exercise? exercise}) {
    final isEditing = exercise != null;

    final nameController = TextEditingController(text: exercise?.name ?? '');
    final muscleController = TextEditingController(text: exercise?.muscleGroup ?? '');
    final descController = TextEditingController(text: exercise?.description ?? '');
    final videoController = TextEditingController(text: exercise?.linkVideo ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Редактировать упражнение' : 'Добавить упражнение'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Название *', hintText: 'например, Жим лежа'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: muscleController,
                decoration: const InputDecoration(labelText: 'Группа мышц *', hintText: 'например, Грудь'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Описание', hintText: 'Базовое упражнение...'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: videoController,
                decoration: const InputDecoration(labelText: 'Ссылка на видео', hintText: 'https://example.com/video'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty || muscleController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Заполните обязательные поля (Название и Группа мышц)')),
                );
                return;
              }

              final updatedExercise = Exercise(
                id: exercise?.id,
                name: nameController.text.trim(),
                muscleGroup: muscleController.text.trim(),
                description: descController.text.trim(),
                linkVideo: videoController.text.trim(),
              );

              bool success;
              if (isEditing && exercise.id != null) {
                success = await widget.apiService.updateExercise(exercise.id!, updatedExercise);
              } else {
                success = await widget.apiService.addExercise(updatedExercise);
              }

              if (context.mounted) {
                Navigator.pop(context);
                if (success) {
                  _refreshExercises();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isEditing ? 'Упражнение обновлено' : 'Упражнение добавлено')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ошибка при сохранении на сервере')),
                  );
                }
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Exercise exercise) {
    if (exercise.id == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление'),
        content: Text('Вы действительно хотите удалить "${exercise.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              final success = await widget.apiService.deleteExercise(exercise.id!);
              if (context.mounted) {
                Navigator.pop(context);
                if (success) {
                  _refreshExercises();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Упражнение удалено')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ошибка при удалении')),
                  );
                }
              }
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  void _showDetailsModal(Exercise exercise) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    exercise.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (!exercise.isGeneral) ...[
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () {
                      Navigator.pop(context);
                      _showExerciseDialog(exercise: exercise);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmDelete(exercise);
                    },
                  ),
                ] else ...[
                  const Tooltip(
                    message: 'Базовое упражнение',
                    child: Icon(Icons.star, color: Colors.amber, size: 28),
                  ),
                ],
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Группа мышц:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            Text(exercise.muscleGroup, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            if (exercise.description != null && exercise.description!.isNotEmpty) ...[
              const Text('Описание:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              Text(exercise.description!, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 12),
            ],
            if (exercise.linkVideo != null && exercise.linkVideo!.isNotEmpty) ...[
              const Text('Видео выполнения:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              VideoPlayerWidget(videoUrl: exercise.linkVideo!),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout App — Упражнения'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshExercises,
          ),
        ],
      ),
      body: FutureBuilder<List<Exercise>>(
        future: _exercisesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(
                      'Не удалось подключиться к бэкенду:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refreshExercises,
                      child: const Text('Повторить попытку'),
                    ),
                  ],
                ),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Список упражнений пуст'));
          }

          final allExercises = snapshot.data!;

          // Собираем уникальный список групп мышц для чипсов фильтра
          final categories = ['Все', ...allExercises.map((e) => e.muscleGroup).toSet().toList()];

          // Формируем элементы для отображения в зависимости от выбранного фильтра
          List<dynamic> displayItems = [];

          if (_selectedCategory == 'Все') {
            // Группируем упражнения по группам мышц
            final Map<String, List<Exercise>> grouped = {};
            for (var ex in allExercises) {
              grouped.putIfAbsent(ex.muscleGroup, () => []).add(ex);
            }

            // Заполняем список: сначала название группы (String), затем её упражнения (Exercise)
            grouped.forEach((group, exercises) {
              displayItems.add(group);
              displayItems.addAll(exercises);
            });
          } else {
            // Если выбрана конкретная категория, показываем только её упражнения
            displayItems = allExercises.where((e) => e.muscleGroup == _selectedCategory).toList();
          }

          return Column(
            children: [
              // Горизонтальный список чипсов (фильтров)
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isSelected = category == _selectedCategory;
                    return Padding(
                      padding: EdgeInsets.only(
                        left: index == 0 ? 16 : 6,
                        right: index == categories.length - 1 ? 16 : 6,
                      ),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = category;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),

              // Список элементов (заголовки блоков + карточки упражнений)
              Expanded(
                child: displayItems.isEmpty
                    ? const Center(child: Text('В этой категории пока нет упражнений'))
                    : ListView.builder(
                  itemCount: displayItems.length,
                  itemBuilder: (context, index) {
                    final item = displayItems[index];

                    // Если элемент — строка, значит это заголовок блока (группа мышц)
                    if (item is String) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text(
                          item,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                      );
                    }

                    // Иначе это карточка упражнения
                    final exercise = item as Exercise;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.fitness_center),
                        ),
                        title: Text(exercise.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Группа мышц: ${exercise.muscleGroup}'),
                        trailing: exercise.isGeneral
                            ? const Tooltip(
                          message: 'Базовое упражнение',
                          child: Icon(Icons.star, color: Colors.amber),
                        )
                            : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                              onPressed: () => _showExerciseDialog(exercise: exercise),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _confirmDelete(exercise),
                            ),
                          ],
                        ),
                        onTap: () => _showDetailsModal(exercise),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showExerciseDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}


