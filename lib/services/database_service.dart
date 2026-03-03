import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/movie_models.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'movie_streaming.db');
    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE movies(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        overview TEXT,
        posterPath TEXT,
        backdropPath TEXT,
        videoUrl TEXT,
        webPlayerUrl TEXT,
        voteAverage REAL,
        releaseDate TEXT,
        watchProgress INTEGER,
        duration INTEGER,
        telegramFileId TEXT,
        telegramAccessHash TEXT,
        telegramPeerId TEXT,
        telegramFileName TEXT,
        telegramFileSize INTEGER,
        category TEXT,
        isTelegram INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE series(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        overview TEXT,
        posterPath TEXT,
        backdropPath TEXT,
        voteAverage REAL,
        firstAirDate TEXT,
        category TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE seasons(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        seriesId INTEGER,
        seasonNumber INTEGER,
        title TEXT,
        overview TEXT,
        posterPath TEXT,
        FOREIGN KEY (seriesId) REFERENCES series (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE episodes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        seasonId INTEGER,
        episodeNumber INTEGER,
        title TEXT,
        overview TEXT,
        stillPath TEXT,
        videoUrl TEXT,
        webPlayerUrl TEXT,
        watchProgress INTEGER,
        duration INTEGER,
        telegramFileId TEXT,
        telegramAccessHash TEXT,
        telegramPeerId TEXT,
        telegramFileName TEXT,
        telegramFileSize INTEGER,
        isTelegram INTEGER DEFAULT 0,
        FOREIGN KEY (seasonId) REFERENCES seasons (id) ON DELETE CASCADE
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE movies ADD COLUMN webPlayerUrl TEXT DEFAULT ""');
      await db.execute('ALTER TABLE episodes ADD COLUMN webPlayerUrl TEXT DEFAULT ""');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE movies ADD COLUMN telegramFileId TEXT');
      await db.execute('ALTER TABLE movies ADD COLUMN telegramAccessHash TEXT');
      await db.execute('ALTER TABLE movies ADD COLUMN telegramPeerId TEXT');
      await db.execute('ALTER TABLE movies ADD COLUMN telegramFileName TEXT');
      await db.execute('ALTER TABLE movies ADD COLUMN telegramFileSize INTEGER');
      await db.execute('ALTER TABLE movies ADD COLUMN isTelegram INTEGER DEFAULT 0');

      await db.execute('ALTER TABLE episodes ADD COLUMN telegramFileId TEXT');
      await db.execute('ALTER TABLE episodes ADD COLUMN telegramAccessHash TEXT');
      await db.execute('ALTER TABLE episodes ADD COLUMN telegramPeerId TEXT');
      await db.execute('ALTER TABLE episodes ADD COLUMN telegramFileName TEXT');
      await db.execute('ALTER TABLE episodes ADD COLUMN telegramFileSize INTEGER');
      await db.execute('ALTER TABLE episodes ADD COLUMN isTelegram INTEGER DEFAULT 0');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE movies ADD COLUMN category TEXT');
      await db.execute('ALTER TABLE series ADD COLUMN category TEXT');
    }
  }

  // Movie CRUD
  Future<int> insertMovie(Movie movie) async {
    Database db = await database;
    return await db.insert('movies', movie.toMap());
  }

  Future<List<Movie>> getMovies() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('movies');
    return List.generate(maps.length, (i) => Movie.fromMap(maps[i]));
  }

  Future<void> updateMovie(Movie movie) async {
    Database db = await database;
    await db.update(
      'movies',
      movie.toMap(),
      where: 'id = ?',
      whereArgs: [movie.id],
    );
  }

  Future<void> deleteMovie(int id) async {
    Database db = await database;
    await db.delete('movies', where: 'id = ?', whereArgs: [id]);
  }

  // Series CRUD
  Future<int> insertSeries(Series series) async {
    Database db = await database;
    return await db.insert('series', series.toMap());
  }

  Future<List<Series>> getSeriesList() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('series');
    return List.generate(maps.length, (i) => Series.fromMap(maps[i]));
  }

  Future<void> updateSeries(Series series) async {
    Database db = await database;
    await db.update(
      'series',
      series.toMap(),
      where: 'id = ?',
      whereArgs: [series.id],
    );
  }

  Future<void> deleteSeries(int id) async {
    Database db = await database;
    await db.delete('seasons', where: 'seriesId = ?', whereArgs: [id]);
    await db.delete('series', where: 'id = ?', whereArgs: [id]);
  }

  // Season CRUD
  Future<int> insertSeason(Season season) async {
    Database db = await database;
    return await db.insert('seasons', season.toMap());
  }

  Future<List<Season>> getSeasons(int seriesId) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'seasons',
      where: 'seriesId = ?',
      whereArgs: [seriesId],
    );
    return List.generate(maps.length, (i) => Season.fromMap(maps[i]));
  }

  // Episode CRUD
  Future<int> insertEpisode(Episode episode) async {
    Database db = await database;
    return await db.insert('episodes', episode.toMap());
  }

  Future<List<Episode>> getEpisodes(int seasonId) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'episodes',
      where: 'seasonId = ?',
      whereArgs: [seasonId],
    );
    return List.generate(maps.length, (i) => Episode.fromMap(maps[i]));
  }

  Future<Episode?> getEpisodeById(int id) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'episodes',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) return Episode.fromMap(maps.first);
    return null;
  }

  Future<void> updateEpisode(Episode episode) async {
    Database db = await database;
    await db.update(
      'episodes',
      episode.toMap(),
      where: 'id = ?',
      whereArgs: [episode.id],
    );
  }

  Future<String> getDbPath() async {
    return join(await getDatabasesPath(), 'movie_streaming.db');
  }
}
