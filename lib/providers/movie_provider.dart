import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/movie_models.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';
import '../services/telegram_service.dart';

class MovieProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final ApiService _apiService = ApiService();

  List<Movie> _movies = [];
  List<Series> _seriesList = [];
  String _apiKey = '';
  bool _useNativePlayer = false;

  // Telegram Settings
  String _tgBotToken = '';
  String _tgBotUsername = '';
  String _tgApiId = '';
  String _tgApiHash = '';
  String _tgPhoneNumber = '';
  bool _tgIsLoggedIn = false;

  List<Movie> get movies => _movies;
  List<Series> get seriesList => _seriesList;
  String get apiKey => _apiKey;
  bool get useNativePlayer => _useNativePlayer;

  String get tgBotToken => _tgBotToken;
  String get tgBotUsername => _tgBotUsername;
  String get tgApiId => _tgApiId;
  String get tgApiHash => _tgApiHash;
  String get tgPhoneNumber => _tgPhoneNumber;
  bool get tgIsLoggedIn => _tgIsLoggedIn;

  MovieProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString('api_key') ?? '';
    _useNativePlayer = prefs.getBool('use_native_player') ?? false;
    _apiService.apiKey = _apiKey;

    _tgBotToken = prefs.getString('tg_bot_token') ?? '';
    _tgBotUsername = prefs.getString('tg_bot_username') ?? '';
    _tgApiId = prefs.getString('tg_api_id') ?? '';
    _tgApiHash = prefs.getString('tg_api_hash') ?? '';
    _tgPhoneNumber = prefs.getString('tg_phone_number') ?? '';
    _tgIsLoggedIn = prefs.getBool('tg_is_logged_in') ?? false;

    if (_tgApiId.isNotEmpty && _tgApiHash.isNotEmpty) {
       TelegramService.initClient(
          apiId: _tgApiId,
          apiHash: _tgApiHash,
          dbPath: 'telegram_session',
       );
    }

    notifyListeners();
  }

  set apiKey(String value) {
    _apiKey = value;
    _apiService.apiKey = value;
    SharedPreferences.getInstance().then((prefs) => prefs.setString('api_key', value));
    notifyListeners();
  }

  set useNativePlayer(bool value) {
    _useNativePlayer = value;
    SharedPreferences.getInstance().then((prefs) => prefs.setBool('use_native_player', value));
    notifyListeners();
  }

  Future<void> saveTelegramConfig({
    required String botToken,
    required String botUsername,
    required String apiId,
    required String apiHash,
    required String phoneNumber,
  }) async {
    _tgBotToken = botToken;
    _tgBotUsername = botUsername;
    _tgApiId = apiId;
    _tgApiHash = apiHash;
    _tgPhoneNumber = phoneNumber;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tg_bot_token', botToken);
    await prefs.setString('tg_bot_username', botUsername);
    await prefs.setString('tg_api_id', apiId);
    await prefs.setString('tg_api_hash', apiHash);
    await prefs.setString('tg_phone_number', phoneNumber);

    notifyListeners();
  }

  set tgIsLoggedIn(bool value) {
    _tgIsLoggedIn = value;
    SharedPreferences.getInstance().then((prefs) => prefs.setBool('tg_is_logged_in', value));
    notifyListeners();
  }

  Future<void> fetchMovies() async {
    _movies = await _dbService.getMovies();
    notifyListeners();
  }

  Future<void> fetchSeriesList() async {
    _seriesList = await _dbService.getSeriesList();
    notifyListeners();
  }

  Future<String> _saveLocalImage(String path) async {
    if (path.isEmpty || path.startsWith('http')) return path;

    final file = File(path);
    if (!file.existsSync()) return '';

    final appDir = await getApplicationDocumentsDirectory();
    final fileName = p.basename(path);
    final savedPath = p.join(appDir.path, 'images', fileName);

    final savedFile = File(savedPath);
    if (!savedFile.parent.existsSync()) {
      savedFile.parent.createSync(recursive: true);
    }

    await file.copy(savedPath);
    return savedPath;
  }

  Future<void> addMovie(Movie movie) async {
    final poster = await _saveLocalImage(movie.posterPath);
    final backdrop = await _saveLocalImage(movie.backdropPath);

    final finalMovie = Movie(
      title: movie.title,
      overview: movie.overview,
      posterPath: poster,
      backdropPath: backdrop,
      videoUrl: movie.videoUrl,
      webPlayerUrl: movie.webPlayerUrl,
      voteAverage: movie.voteAverage,
      releaseDate: movie.releaseDate,
    );

    await _dbService.insertMovie(finalMovie);
    await fetchMovies();
  }

  Future<void> updateMovieFull(Movie movie) async {
    final poster = await _saveLocalImage(movie.posterPath);
    final backdrop = await _saveLocalImage(movie.backdropPath);

    final finalMovie = Movie(
      id: movie.id,
      title: movie.title,
      overview: movie.overview,
      posterPath: poster,
      backdropPath: backdrop,
      videoUrl: movie.videoUrl,
      webPlayerUrl: movie.webPlayerUrl,
      voteAverage: movie.voteAverage,
      releaseDate: movie.releaseDate,
      watchProgress: movie.watchProgress,
      duration: movie.duration,
    );

    await _dbService.updateMovie(finalMovie);
    await fetchMovies();
  }

  Future<void> updateMovieProgress(int movieId, int progress) async {
    final movieIdx = _movies.indexWhere((m) => m.id == movieId);
    if (movieIdx != -1) {
       final movie = _movies[movieIdx];
       final updatedMovie = Movie(
         id: movie.id,
         title: movie.title,
         overview: movie.overview,
         posterPath: movie.posterPath,
         backdropPath: movie.backdropPath,
         videoUrl: movie.videoUrl,
         webPlayerUrl: movie.webPlayerUrl,
         voteAverage: movie.voteAverage,
         releaseDate: movie.releaseDate,
         watchProgress: progress,
         duration: movie.duration,
       );
       await _dbService.updateMovie(updatedMovie);
       _movies[movieIdx] = updatedMovie;
       notifyListeners();
    }
  }

  Future<void> deleteMovie(int id) async {
    await _dbService.deleteMovie(id);
    await fetchMovies();
  }

  Future<void> updateSeriesFull(Series series) async {
    final poster = await _saveLocalImage(series.posterPath);
    final backdrop = await _saveLocalImage(series.backdropPath);

    final finalSeries = Series(
      id: series.id,
      title: series.title,
      overview: series.overview,
      posterPath: poster,
      backdropPath: backdrop,
      voteAverage: series.voteAverage,
      firstAirDate: series.firstAirDate,
    );

    await _dbService.updateSeries(finalSeries);
    await fetchSeriesList();
  }

  Future<void> deleteSeries(int id) async {
    await _dbService.deleteSeries(id);
    await fetchSeriesList();
  }

  Future<void> updateEpisodeProgress(int episodeId, int progress) async {
    final ep = await _dbService.getEpisodeById(episodeId);
    if (ep != null) {
       final updatedEp = Episode(
         id: ep.id,
         seasonId: ep.seasonId,
         episodeNumber: ep.episodeNumber,
         title: ep.title,
         overview: ep.overview,
         stillPath: ep.stillPath,
         videoUrl: ep.videoUrl,
         webPlayerUrl: ep.webPlayerUrl,
         watchProgress: progress,
         duration: ep.duration,
       );
       await _dbService.updateEpisode(updatedEp);
       notifyListeners();
    }
  }

  Future<void> updateEpisodeFull(Episode ep) async {
       await _dbService.updateEpisode(ep);
       notifyListeners();
  }

  Future<void> addSeriesManual(Series series) async {
    final poster = await _saveLocalImage(series.posterPath);
    final backdrop = await _saveLocalImage(series.backdropPath);

    final finalSeries = Series(
      title: series.title,
      overview: series.overview,
      posterPath: poster,
      backdropPath: backdrop,
      voteAverage: series.voteAverage,
      firstAirDate: series.firstAirDate,
    );

    await _dbService.insertSeries(finalSeries);
    await fetchSeriesList();
  }

  Future<void> addSeriesWithMetadata(Map<String, dynamic> seriesData) async {
    final series = Series(
      title: seriesData['name'] ?? '',
      overview: seriesData['overview'] ?? '',
      posterPath: seriesData['poster_path'] != null ? 'https://image.tmdb.org/t/p/w500${seriesData['poster_path']}' : '',
      backdropPath: seriesData['backdrop_path'] != null ? 'https://image.tmdb.org/t/p/original${seriesData['backdrop_path']}' : '',
      voteAverage: (seriesData['vote_average'] as num?)?.toDouble() ?? 0.0,
      firstAirDate: seriesData['first_air_date'] ?? '',
    );

    int seriesId = await _dbService.insertSeries(series);
    int tmdbId = seriesData['id'];

    final seasons = await _apiService.getSeasons(tmdbId, seriesId);
    for (var season in seasons) {
      if (season.seasonNumber == 0) continue;
      int seasonId = await _dbService.insertSeason(season);
      final episodes = await _apiService.getEpisodes(tmdbId, season.seasonNumber, seasonId);
      for (var ep in episodes) {
        await _dbService.insertEpisode(ep);
      }
    }
    await fetchSeriesList();
  }

  Future<List<Movie>> searchMovies(String query) async {
    return await _apiService.searchMovies(query);
  }

  Future<List<Map<String, dynamic>>> searchSeries(String query) async {
    return await _apiService.searchSeriesRaw(query);
  }
}
