import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Enforces the cat/human surface boundary.
///
/// This is not a normal test. It is the guardrail described in CLAUDE.md: a cat
/// tapping an ad reads as invalid traffic to AdMob and the penalty is account
/// suspension, so the cat surface must be structurally incapable of showing one.
/// If this fails, move the code. Do not relax the test.
void main() {
  const forbidden = <String, String>{
    'google_mobile_ads': 'ad SDK — cats generate invalid clicks',
    'purchases_flutter': 'purchase SDK — accidental purchases',
    'in_app_purchase': 'purchase SDK — accidental purchases',
    'url_launcher': 'leaves the app',
    'share_plus': 'leaves the app',
    'human/store': 'monetization lives on the human surface only',
    'human/settings': 'settings must not be reachable from a paw',
  };

  test('cat surface imports nothing that can take money or leave the app', () {
    final catDir = Directory('lib/cat');
    expect(catDir.existsSync(), isTrue, reason: 'run from the project root');

    final violations = <String>[];

    for (final entity in catDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (!line.startsWith('import ') && !line.startsWith('export ')) continue;

        for (final entry in forbidden.entries) {
          if (line.contains(entry.key)) {
            violations.add('${entity.path}:${i + 1} -> ${entry.key} (${entry.value})');
          }
        }
      }
    }

    expect(violations, isEmpty, reason: 'Boundary violations:\n${violations.join('\n')}');
  });

  test('cat surface shows no dialogs, snackbars, or bottom sheets', () {
    // A cat produces hundreds of taps. Anything that a single tap can summon
    // will be summoned, repeatedly, and will end the session.
    const banned = ['showDialog', 'showModalBottomSheet', 'ScaffoldMessenger'];
    final violations = <String>[];

    for (final entity in Directory('lib/cat').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final symbol in banned) {
        if (source.contains(symbol)) violations.add('${entity.path} -> $symbol');
      }
    }

    expect(violations, isEmpty, reason: 'Banned UI on cat surface:\n${violations.join('\n')}');
  });
}
