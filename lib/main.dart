
import 'package:cbl/cbl.dart';
import 'package:cbl_flutter/cbl_flutter.dart';
import 'package:flutter/material.dart';

class MyMood {
  final String message;

  MyMood({required this.message});

  factory MyMood.fromJson(Map<String, dynamic> json) {
    return MyMood(
      message: json['message'],
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'message': message,
    };
  }
}

class LocalDatabaseService {
  AsyncDatabase? database;  

  Future<void> init() async {
    database ??= await Database.openAsync('database');  
  }

    Future<bool> addMood(MyMood mood) async {
    final collection = await database?.createCollection('moods');
    if (collection != null) {
      final document = MutableDocument(mood.toMap());
      return await collection.saveDocument(document);
    }
    return false;
  }

    Future<MyMood?> fetchMood() async {
    final collection = await database?.createCollection('moods');
    if (collection != null) {
      final query = await database?.createQuery(
        'SELECT * FROM moods',
      );
      final result = await query?.execute();
      final results = await result?.allResults();
      if (results != null && results.isNotEmpty) {
        final data = results.first.toPlainMap();
        return MyMood.fromJson(data);
      }
    }
    return null;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Inicializar o Flutter
  await CouchbaseLiteFlutter.init(); // Inicializar o Couchbase
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'App de Humor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MoodScreen(),
    );
  }
}

class MoodScreen extends StatefulWidget {
  @override
  _MoodScreenState createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  String _moodMessage = "Estou feliz";
  final TextEditingController _controller = TextEditingController();
  final LocalDatabaseService _dbService = LocalDatabaseService();

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
  }

  Future<void> _initializeDatabase() async {
    await _dbService.init();
    _loadMood();
  }

  Future<void> _loadMood() async {
    try {
      final storedMood = await _dbService.fetchMood();
      if (storedMood != null) {
        setState(() {
          _moodMessage = storedMood.message;
        });
      } else {
        setState(() {
          _moodMessage = "Estou feliz";
        });
      }
    } catch (e) {
      setState(() {
        _moodMessage = "Estou feliz";
      });
    }
  }

  void _saveMood() async {
    if (_controller.text.isNotEmpty) {
      final newMood = MyMood(message: _controller.text);
      bool isSaved = await _dbService.addMood(newMood);
      if (isSaved) {
        setState(() {
          _moodMessage = _controller.text;
        });
        _controller.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Seu Humor do Dia'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Seu Humor:',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              _moodMessage,
              style: TextStyle(fontSize: 20, fontStyle: FontStyle.italic),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Digite uma frase sobre o seu humor',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saveMood,
              child: Text('Salvar Humor'),
            ),
          ],
        ),
      ),
    );
  }
}

