import 'package:cat_tv_games/cat/audio/cat_audio.dart';
import 'package:cat_tv_games/cat/engine/cat_game.dart';
import 'package:cat_tv_games/cat/games/fish/fish_game.dart';
import 'package:cat_tv_games/cat/games/game_catalog.dart';
import 'package:cat_tv_games/cat/games/laser/laser_game.dart';
import 'package:cat_tv_games/cat/render/cat_surface.dart';
import 'package:cat_tv_games/cat/render/cat_surface_games.dart';
import 'package:cat_tv_games/data/models/cat_profile.dart';
import 'package:cat_tv_games/data/repositories/cat_profile_repository.dart';
import 'package:cat_tv_games/human/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A mode is registered in three places — the rules catalog, the renderer map
/// and the blurbs — and nothing but this file stops one of them being
/// forgotten. A mode with rules and no renderer is a crash on launch; a mode
/// with a renderer and no rules is a card that does nothing.
void main() {
  group('the registries agree', () {
    test('every mode has rules, a renderer and something to say about it', () {
      expect(gameCatalog.keys, isNotEmpty);
      for (final id in gameCatalog.keys) {
        expect(
          catSurfaceGames[id],
          isNotNull,
          reason: '$id has rules but nothing draws it',
        );
        expect(
          modeBlurbs[id],
          isNotNull,
          reason: '$id would show a blank line in the picker',
        );
      }
    });

    test('no renderer is registered for a mode that does not exist', () {
      for (final id in catSurfaceGames.keys) {
        expect(
          gameCatalog[id],
          isNotNull,
          reason: '$id draws something with no rules behind it',
        );
      }
    });

    test('both modes are actually there', () {
      expect(
        gameCatalog.keys,
        containsAll([FishGame.gameId, LaserGame.gameId]),
      );
    });

    test('every registered mode builds', () {
      for (final id in catSurfaceGames.keys) {
        final surface = catSurfaceGames[id]!(
          audio: SilentCatAudio(),
          limits: const SessionLimits(),
        );
        expect(surface.rules.id, id, reason: '$id is wired to the wrong rules');
      }
    });
  });

  group('the picker', () {
    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            cats: InMemoryCatProfileRepository(
              const CatProfile(id: 'moss', name: 'Moss'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('offers every registered mode', (tester) async {
      await open(tester);
      for (final id in gameCatalog.keys) {
        expect(
          find.text(gameCatalog[id]!().displayName),
          findsOneWidget,
          reason: '$id is registered but not offered',
        );
      }
    });

    testWidgets('starts the mode that was picked, not always the pond', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('Laser dot'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Let the cat play'));
      // Plain pumps: a running game always has another frame scheduled, so
      // pumpAndSettle would wait forever rather than tell you anything.
      await tester.pump();
      await tester.pump();

      final surface = tester.widget<CatSurface>(find.byType(CatSurface));
      expect(surface.mode, LaserGame.gameId);
    });

    testWidgets('the pond is what a session opens with by default', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('Let the cat play'));
      await tester.pump();
      await tester.pump();

      final surface = tester.widget<CatSurface>(find.byType(CatSurface));
      expect(
        surface.mode,
        FishGame.gameId,
        reason: 'NEXT_STEPS.md says find out about the fish first',
      );
    });
  });

  testWidgets('an unknown mode falls back rather than crashing', (
    tester,
  ) async {
    // This is the surface a cat is left alone with. A bad id should cost a
    // wrong pond, not a dead screen nobody is watching.
    await tester.pumpWidget(
      MaterialApp(
        home: CatSurface(
          onExit: () {},
          profile: const CatProfile(id: 'moss', name: 'Moss'),
          mode: 'no-such-mode',
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
