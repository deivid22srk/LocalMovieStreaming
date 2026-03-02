import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/movie_models.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';

class MovieProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final ApiService _apiService = ApiService();

  List<Movie> _movies = [];
  List<Series> _seriesList = [];
  String _apiKey = '';

  List<Movie> get movies => _movies;
  List<Series> get seriesList => _seriesList;
  String get apiKey => _apiKey;

  set apiKey(String value) {
    _apiKey = value;
    _apiService.apiKey = value;
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
      voteAverage: movie.voteAverage,
      releaseDate: movie.releaseDate,
    );

    await _dbService.insertMovie(finalMovie);
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
         watchProgress: progress,
         duration: ep.duration,
       );
       await _dbService.updateEpisode(updatedEp);
       notifyListeners();
    }
  }

  Future<void> updateEpisodeUrl(int episodeId, String url) async {
    final ep = await _dbService.getEpisodeById(episodeId);
    if (ep != null) {
       final updatedEp = Episode(
         id: ep.id,
         seasonId: ep.seasonId,
         episodeNumber: ep.episodeNumber,
         title: ep.title,
         overview: ep.overview,
         stillPath: ep.stillPath,
         videoUrl: url,
         watchProgress: ep.watchProgress,
         duration: ep.duration,
       );
       await _dbService.updateEpisode(updatedEp);
       notifyListeners();
    }
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
