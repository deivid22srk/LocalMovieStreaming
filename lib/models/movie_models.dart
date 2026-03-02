class Movie {
  final int? id;
  final String title;
  final String overview;
  final String posterPath;
  final String backdropPath;
  final String videoUrl;
  final double voteAverage;
  final String releaseDate;
  final int watchProgress; // in milliseconds
  final int duration; // in milliseconds

  Movie({
    this.id,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.videoUrl,
    required this.voteAverage,
    required this.releaseDate,
    this.watchProgress = 0,
    this.duration = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'overview': overview,
      'posterPath': posterPath,
      'backdropPath': backdropPath,
      'videoUrl': videoUrl,
      'voteAverage': voteAverage,
      'releaseDate': releaseDate,
      'watchProgress': watchProgress,
      'duration': duration,
    };
  }

  factory Movie.fromMap(Map<String, dynamic> map) {
    return Movie(
      id: map['id'],
      title: map['title'],
      overview: map['overview'],
      posterPath: map['posterPath'],
      backdropPath: map['backdropPath'],
      videoUrl: map['videoUrl'],
      voteAverage: map['voteAverage'],
      releaseDate: map['releaseDate'],
      watchProgress: map['watchProgress'] ?? 0,
      duration: map['duration'] ?? 0,
    );
  }
}

class Series {
  final int? id;
  final String title;
  final String overview;
  final String posterPath;
  final String backdropPath;
  final double voteAverage;
  final String firstAirDate;

  Series({
    this.id,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.voteAverage,
    required this.firstAirDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'overview': overview,
      'posterPath': posterPath,
      'backdropPath': backdropPath,
      'voteAverage': voteAverage,
      'firstAirDate': firstAirDate,
    };
  }

  factory Series.fromMap(Map<String, dynamic> map) {
    return Series(
      id: map['id'],
      title: map['title'],
      overview: map['overview'],
      posterPath: map['posterPath'],
      backdropPath: map['backdropPath'],
      voteAverage: map['voteAverage'],
      firstAirDate: map['firstAirDate'],
    );
  }
}

class Season {
  final int? id;
  final int seriesId;
  final int seasonNumber;
  final String title;
  final String overview;
  final String posterPath;

  Season({
    this.id,
    required this.seriesId,
    required this.seasonNumber,
    required this.title,
    required this.overview,
    required this.posterPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'seriesId': seriesId,
      'seasonNumber': seasonNumber,
      'title': title,
      'overview': overview,
      'posterPath': posterPath,
    };
  }

  factory Season.fromMap(Map<String, dynamic> map) {
    return Season(
      id: map['id'],
      seriesId: map['seriesId'],
      seasonNumber: map['seasonNumber'],
      title: map['title'],
      overview: map['overview'],
      posterPath: map['posterPath'],
    );
  }
}

class Episode {
  final int? id;
  final int seasonId;
  final int episodeNumber;
  final String title;
  final String overview;
  final String stillPath;
  final String videoUrl;
  final int watchProgress;
  final int duration;

  Episode({
    this.id,
    required this.seasonId,
    required this.episodeNumber,
    required this.title,
    required this.overview,
    required this.stillPath,
    required this.videoUrl,
    this.watchProgress = 0,
    this.duration = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'seasonId': seasonId,
      'episodeNumber': episodeNumber,
      'title': title,
      'overview': overview,
      'stillPath': stillPath,
      'videoUrl': videoUrl,
      'watchProgress': watchProgress,
      'duration': duration,
    };
  }

  factory Episode.fromMap(Map<String, dynamic> map) {
    return Episode(
      id: map['id'],
      seasonId: map['seasonId'],
      episodeNumber: map['episodeNumber'],
      title: map['title'],
      overview: map['overview'],
      stillPath: map['stillPath'],
      videoUrl: map['videoUrl'],
      watchProgress: map['watchProgress'] ?? 0,
      duration: map['duration'] ?? 0,
    );
  }
}
