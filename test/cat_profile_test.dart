import 'package:cat_tv_games/cat/engine/paw_input.dart';
import 'package:cat_tv_games/data/models/cat_profile.dart';
import 'package:cat_tv_games/data/repositories/cat_profile_repository.dart';
import 'package:cat_tv_games/human/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether a cat's climb survives the session it happened in.
///
/// CatProfile has carried "persisted across sessions so a cat does not restart
/// at baseline every time" since the first commit, and nothing read it. Every
/// session opened at 0.4, so a cat that spent twenty minutes reaching 0.9 began
/// again at the bottom the next day and the adaptive difficulty only ever meant
/// anything inside one sitting.
void main() {
  group('the assist follows the cat, not just the level', () {
    test('a cat given more generosity gets more reach', () {
      // The other half of CatProfile that nothing read. Kittens and senior cats
      // are supposed to be given more; every cat was getting the same.
      final kitten = PawInputConfig.forDifficulty(0.4, catGenerosity: 0.6);
      final ordinary = PawInputConfig.forDifficulty(0.4, catGenerosity: 0.35);
      final sharp = PawInputConfig.forDifficulty(0.4, catGenerosity: 0.15);

      expect(kitten.generosity, greaterThan(ordinary.generosity));
      expect(ordinary.generosity, greaterThan(sharp.generosity));
    });

    test('the generous tier stays alive for every cat at every level', () {
      // The regression that hides itself: a reach inside the assist radius
      // kills the tier silently — nothing throws, nothing logs, cats just
      // score less. It used to hold only because two constants happened to
      // suit each other, and a low profile generosity would have broken it.
      for (var i = 0; i <= 10; i++) {
        for (final cat in [0.05, 0.15, 0.35, 0.6, 1.0]) {
          final config = PawInputConfig.forDifficulty(
            i / 10,
            catGenerosity: cat,
          );
          final assist = config.minTargetRadius * config.assistMultiplier;
          final reach = PawInputConfig.referenceWidth * config.generosity;
          expect(
            reach,
            greaterThan(assist),
            reason: 'difficulty ${i / 10}, cat generosity $cat',
          );
        }
      }
    });
  });

  group('the repository', () {
    test('hands back the cat it was given, and keeps what it is told',
        () async {
      final cats = InMemoryCatProfileRepository(
        const CatProfile(id: 'moss', name: 'Moss', difficulty: 0.7),
      );

      expect((await cats.current()).difficulty, 0.7);

      await cats.save((await cats.current()).copyWith(difficulty: 0.9));
      expect((await cats.current()).difficulty, 0.9);
      expect((await cats.current()).name, 'Moss', reason: 'same cat');
    });
  });

  group('end to end', () {
    Future<void> hold(WidgetTester tester, Duration total) async {
      const frame = Duration(milliseconds: 50);
      for (var ms = 0; ms < total.inMilliseconds; ms += frame.inMilliseconds) {
        await tester.pump(frame);
      }
    }

    testWidgets('a session starts from the profile and hands it back', (
      tester,
    ) async {
      // Reading the value back out of the repository is not enough on its own,
      // which is worth spelling out because the first version of this test did
      // exactly that and looked convincing. Drop the write-back entirely and
      // the repository still holds 0.9, because nothing overwrote it — the
      // test would pass while half the feature was missing.
      //
      // So the repository records what it was asked to save. That the pond
      // handed back 0.9 rather than the 0.4 default proves the profile reached
      // the game; that anything was saved at all proves it came back.
      final cats = _RecordingCats(
        const CatProfile(id: 'moss', name: 'Moss', difficulty: 0.9),
      );

      await tester.pumpWidget(MaterialApp(home: HomeScreen(cats: cats)));
      await tester.tap(find.text('Let the cat play'));
      // Plain pumps, not pumpAndSettle. The pond is a running game and always
      // has another frame scheduled, so it never settles and the wait times
      // out instead of telling you anything.
      await tester.pump();
      await tester.pump();
      expect(find.text('Let the cat play'), findsNothing);

      // Leave the way a person leaves: the two second hold in the corner.
      await tester.startGesture(const Offset(30, 30));
      await hold(tester, const Duration(seconds: 3));
      expect(find.text('Let the cat play'), findsOneWidget);

      expect(
        cats.saved,
        isNotEmpty,
        reason: 'the session has to write the cat back, not just read it',
      );
      final handedBack = cats.saved.last;
      expect(handedBack.id, 'moss');
      expect(handedBack.name, 'Moss');
      expect(
        handedBack.difficulty,
        0.9,
        reason: 'a session that ignored the profile would hand back 0.4',
      );
    });
  });
}

/// Keeps every save, so a test can tell "nothing was written" apart from
/// "what was written happens to match what was already there".
class _RecordingCats implements CatProfileRepository {
  _RecordingCats(this._profile);

  CatProfile _profile;
  final List<CatProfile> saved = [];

  @override
  Future<CatProfile> current() async => _profile;

  @override
  Future<void> save(CatProfile profile) async {
    saved.add(profile);
    _profile = profile;
  }
}
