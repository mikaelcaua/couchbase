import 'package:cbl/cbl.dart';
import 'package:cbl_flutter/cbl_flutter.dart';
import 'package:flutter/material.dart';

class CouchbaseContants {
  static String userName = 'mooduser';
  static String password = '@Testecapella123';
  static String publicConnectionUrl =
      'wss://0wumbp6bvj2mwzm4.apps.cloud.couchbase.com:4984/moodendpoint';

  static const String channel = 'moodCollection';
  static const String collection = 'moodCollection';
  static const String scope = 'app_scope';
}

class MyMood {
  final String message;

  MyMood({required this.message});

  factory MyMood.fromJson(Map<String, dynamic> json) {
    debugPrint('fromJson: $json');
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
  AsyncReplicator? replicator;

  Future<void> init() async {
    database ??= await Database.openAsync('database');
    startReplication(
      collectionName: CouchbaseContants.collection,
      onSynced: () {
        print('Sincronizado');
      },
    );
  }

  Future<bool> addMood(MyMood mood) async {
    final collection = await database?.createCollection(
      CouchbaseContants.collection,
      CouchbaseContants.scope,
    );
    if (collection != null) {
      final document = MutableDocument(mood.toMap());
      final resultSave = await collection.saveDocument(
        document,
        ConcurrencyControl.lastWriteWins,
      );
      if (resultSave) {
        startReplication(
          collectionName: CouchbaseContants.collection,
          onSynced: () {
            print('Sincronizado');
          },
        );
      }
      return resultSave;
    }
    return false;
  }

  Future<void> startReplication({
    required String collectionName,
    required Function() onSynced,
  }) async {
    final collection = await database?.createCollection(
      collectionName,
      CouchbaseContants.scope,
    );
    if (collection != null) {
      final replicatorConfig = ReplicatorConfiguration(
        target: UrlEndpoint(
          Uri.parse(CouchbaseContants.publicConnectionUrl),
        ),
        authenticator: BasicAuthenticator(
          username: CouchbaseContants.userName,
          password: CouchbaseContants.password,
        ),
        continuous: true,
        replicatorType: ReplicatorType.pushAndPull,
        enableAutoPurge: true,
      );
      replicatorConfig.addCollection(
        collection,
        CollectionConfiguration(
          channels: [CouchbaseContants.channel],
          conflictResolver: ConflictResolver.from(
            (conflict) {
              return conflict.remoteDocument ?? conflict.localDocument;
            },
          ),
        ),
      );
      replicator = await Replicator.createAsync(replicatorConfig);
      replicator?.addChangeListener(
        (change) {
          if (change.status.error != null) {
            print('Ocorreu um erro na replicação');
          }
          if (change.status.activity == ReplicatorActivityLevel.idle) {
            print('ocorreu uma sincronização');
            onSynced();
          }
        },
      );
      await replicator?.start();
    }
  }

  Future<List<MyMood>?> fetch({
    required String collectionName,
    String? filter,
  }) async {
    await init();
    await database?.createCollection(
      collectionName,
      CouchbaseContants.scope,
    );
    final query = await database?.createQuery(
      'SELECT META().id, * FROM ${CouchbaseContants.scope}.$collectionName ${filter != null ? 'WHERE $filter' : ''}',
    );
    final result = await query?.execute();
    final results = await result?.allResults();
    final data = results
        ?.map((e) => {
              'id': e.string('id'),
              ...(e.toPlainMap()[collectionName] as Map<String, dynamic>)
            })
        .toList();
    final moodsFromData = data?.map((e) => MyMood.fromJson(e)).toList();
    return moodsFromData ?? [];
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
      final storedMood =
          await _dbService.fetch(collectionName: 'moodCollection');
      if (storedMood != null) {
        setState(() {
          _moodMessage = storedMood.last.message;
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _saveMood,
                  child: Text('Salvar Humor'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
