import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:local_movie_streaming/main.dart';
import 'package:local_movie_streaming/providers/movie_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => MovieProvider()),
        ],
        child: const MyApp(),
      ),
    );

    // Verify that the app title is present
    expect(find.text('LocalMovieStreaming'), findsOneWidget);

    // Verify that the empty state message is present since we have no movies
    expect(find.text('Nenhum conteúdo adicionado'), findsOneWidget);
  });
}
