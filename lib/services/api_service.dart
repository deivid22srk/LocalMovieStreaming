import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/movie_models.dart';

class ApiService {
  final String _baseUrl = 'https://api.themoviedb.org/3';
  String? apiKey;

  ApiService({this.apiKey});

  Future<List<Movie>> searchMovies(String query) async {
    if (apiKey == null || apiKey!.isEmpty) return [];

    final response = await http.get(
      Uri.parse('$_baseUrl/search/movie?api_key=$apiKey&query=${Uri.encodeComponent(query)}&language=pt-BR'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'];
      return results.map((m) => Movie(
        title: m['title'] ?? '',
        overview: m['overview'] ?? '',
        posterPath: m['poster_path'] != null ? 'https://image.tmdb.org/t/p/w500${m['poster_path']}' : '',
        backdropPath: m['backdrop_path'] != null ? 'https://image.tmdb.org/t/p/original${m['backdrop_path']}' : '',
        videoUrl: '',
        voteAverage: (m['vote_average'] as num?)?.toDouble() ?? 0.0,
        releaseDate: m['release_date'] ?? '',
      )).toList();
    } else {
      throw Exception('Failed to load movies');
    }
  }

  Future<List<Map<String, dynamic>>> searchSeriesRaw(String query) async {
    if (apiKey == null || apiKey!.isEmpty) return [];

    final response = await http.get(
      Uri.parse('$_baseUrl/search/tv?api_key=$apiKey&query=${Uri.encodeComponent(query)}&language=pt-BR'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'];
      return List<Map<String, dynamic>>.from(results);
    } else {
      throw Exception('Failed to load series');
    }
  }

  Future<List<Season>> getSeasons(int tvId, int seriesId) async {
     if (apiKey == null || apiKey!.isEmpty) return [];

     final response = await http.get(
      Uri.parse('$_baseUrl/tv/$tvId?api_key=$apiKey&language=pt-BR'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List seasonsData = data['seasons'] ?? [];
      return seasonsData.map((s) => Season(
        seriesId: seriesId,
        seasonNumber: s['season_number'],
        title: s['name'] ?? 'Temporada ${s['season_number']}',
        overview: s['overview'] ?? '',
        posterPath: s['poster_path'] != null ? 'https://image.tmdb.org/t/p/w500${s['poster_path']}' : '',
      )).toList();
    }
    return [];
  }

  Future<List<Episode>> getEpisodes(int tvId, int seasonNumber, int seasonId) async {
    if (apiKey == null || apiKey!.isEmpty) return [];

    final response = await http.get(
      Uri.parse('$_baseUrl/tv/$tvId/season/$seasonNumber?api_key=$apiKey&language=pt-BR'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List episodesData = data['episodes'] ?? [];
      return episodesData.map((e) => Episode(
        seasonId: seasonId,
        episodeNumber: e['episode_number'],
        title: e['name'] ?? 'Episódio ${e['episode_number']}',
        overview: e['overview'] ?? '',
        stillPath: e['still_path'] != null ? 'https://image.tmdb.org/t/p/w500${e['still_path']}' : '',
        videoUrl: '',
      )).toList();
    }
    return [];
  }
}
