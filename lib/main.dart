import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_player_iframe/youtube_player_iframe.dart';


void main() {
  runApp(const WorkoutApp());
}

// ---------------------------------------------------------------------------
// 1. Модель данных (со всеми 4 полями + id)
// ---------------------------------------------------------------------------
class Exercise {
  final String? id;
  final String name;
  final String muscleGroup;
  final String? description;
  final String? linkVideo;

  Exercise({
    this.id,
    required this.name,
    required this.muscleGroup,
    this.description,
    this.linkVideo,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id']?.toString(),
      name: json['name'],
      muscleGroup: json['muscleGroup'],
      description: json['description'],
      linkVideo: json['linkVideo'],
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
// 2. Сервис для работы с API Spring Boot (CRUD)
// ---------------------------------------------------------------------------
class ApiService {
  static const String baseUrl = 'http://10.0.2.2:8080/exercises';

  // GET /exercises/all
  Future<List<Exercise>> getExercises() async {
    final response = await http.get(Uri.parse('$baseUrl/all'));

    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((dynamic item) => Exercise.fromJson(item)).toList();
    } else {
      throw Exception('Ошибка загрузки: ${response.statusCode}');
    }
  }

  // POST /exercises/create
  Future<bool> addExercise(Exercise exercise) async {
    final response = await http.post(
      Uri.parse('$baseUrl/create'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: utf8.encode(jsonEncode(exercise.toJson())),
    );

    return response.statusCode == 200 || response.statusCode == 201;
  }

  // PUT /exercises/update/{id}
  Future<bool> updateExercise(String id, Exercise exercise) async {
    final response = await http.put(
      Uri.parse('$baseUrl/update/$id'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: utf8.encode(jsonEncode(exercise.toJson())),
    );

    return response.statusCode == 200 || response.statusCode == 201;
  }

  // DELETE /exercises/delete/{id}
  Future<bool> deleteExercise(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/delete/$id'),
    );

    return response.statusCode == 200 || response.statusCode == 204;
  }
}
//Для отображения видео
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
// 3. Главный интерфейс приложения
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
      home: const ExercisesScreen(),
    );
  }
}

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Exercise>> _exercisesFuture;

  @override
  void initState() {
    super.initState();
    _refreshExercises();
  }

  void _refreshExercises() {
    setState(() {
      _exercisesFuture = _apiService.getExercises();
    });
  }

  // Диалог добавления / редактирования упражнения
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
                decoration: const InputDecoration(
                  labelText: 'Название *',
                  hintText: 'например, Жим лежа',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: muscleController,
                decoration: const InputDecoration(
                  labelText: 'Группа мышц *',
                  hintText: 'например, Грудь',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Описание',
                  hintText: 'Базовое упражнение...',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: videoController,
                decoration: const InputDecoration(
                  labelText: 'Ссылка на видео',
                  hintText: 'https://example.com/video',
                ),
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
                success = await _apiService.updateExercise(exercise.id!, updatedExercise);
              } else {
                success = await _apiService.addExercise(updatedExercise);
              }

              if (context.mounted) {
                Navigator.pop(context);
                if (success) {
                  _refreshExercises();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEditing ? 'Упражнение обновлено' : 'Упражнение добавлено'),
                    ),
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

  // Подтверждение удаления
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
              final success = await _apiService.deleteExercise(exercise.id!);
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

  // Просмотр полной информации об упражнении
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
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            Text('Группа мышц:', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            Text(exercise.muscleGroup, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            if (exercise.description != null && exercise.description!.isNotEmpty) ...[
              const Text('Описание:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              Text(exercise.description!, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 12),
            ],
            // ... внутри _showDetailsModal(Exercise exercise) ...

            if (exercise.linkVideo != null && exercise.linkVideo!.isNotEmpty) ...[
              const Text(
                'Видео выполнения:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              // Вместо SelectableText вставляем сам плеер:
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

          final exercises = snapshot.data!;
          return ListView.builder(
            itemCount: exercises.length,
            itemBuilder: (context, index) {
              final item = exercises[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.fitness_center),
                  ),
                  title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Группа мышц: ${item.muscleGroup}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                        onPressed: () => _showExerciseDialog(exercise: item),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _confirmDelete(item),
                      ),
                    ],
                  ),
                  onTap: () => _showDetailsModal(item),
                ),
              );
            },
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