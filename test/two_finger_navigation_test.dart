import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant_braille/accessibility/two_finger_navigation_detector.dart';

void main() {
  testWidgets('opt-in two-finger left and right swipes report next and previous', (tester) async {
    final directions = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TwoFingerNavigationDetector(
          enabled: true,
          onSwipe: directions.add,
          child: const SizedBox.expand(key: ValueKey('gesture-surface')),
        ),
      ),
    ));
    final rect = tester.getRect(find.byKey(const ValueKey('gesture-surface')));

    final leftA = await tester.startGesture(Offset(rect.left + 220, rect.top + 120), pointer: 1);
    final leftB = await tester.startGesture(Offset(rect.left + 400, rect.top + 120), pointer: 2);
    await leftA.moveTo(Offset(rect.left + 80, rect.top + 120));
    await leftB.moveTo(Offset(rect.left + 260, rect.top + 120));
    await tester.pump();
    await leftA.up();
    await leftB.up();
    expect(directions, [1]);

    final rightA = await tester.startGesture(Offset(rect.left + 80, rect.top + 220), pointer: 3);
    final rightB = await tester.startGesture(Offset(rect.left + 260, rect.top + 220), pointer: 4);
    await rightA.moveTo(Offset(rect.left + 220, rect.top + 220));
    await rightB.moveTo(Offset(rect.left + 400, rect.top + 220));
    await tester.pump();
    await rightA.up();
    await rightB.up();
    expect(directions, [1, -1]);
  });

  testWidgets('one-finger and disabled gestures never navigate', (tester) async {
    final directions = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TwoFingerNavigationDetector(
          enabled: false,
          onSwipe: directions.add,
          child: const SizedBox.expand(key: ValueKey('gesture-surface')),
        ),
      ),
    ));
    final rect = tester.getRect(find.byKey(const ValueKey('gesture-surface')));
    final oneFinger = await tester.startGesture(Offset(rect.left + 220, rect.top + 120));
    await oneFinger.moveTo(Offset(rect.left + 50, rect.top + 120));
    await tester.pump();
    await oneFinger.up();
    expect(directions, isEmpty);
  });
}
