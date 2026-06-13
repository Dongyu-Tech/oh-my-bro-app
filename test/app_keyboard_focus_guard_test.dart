import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heymybro/shared/widgets/app_keyboard_focus_guard.dart';

void main() {
  testWidgets('route change unfocuses an active TextField', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [AppKeyboardFocusRouteObserver()],
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                TextField(focusNode: focusNode),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(body: Text('next page')),
                    ),
                  ),
                  child: const Text('go'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(focusNode.hasFocus, isFalse);
  });

  testWidgets('hiding the keyboard (viewInsets -> 0) unfocuses an active '
      'TextField', (tester) async {
    addTearDown(tester.view.resetViewInsets);

    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AppKeyboardFocusGuard(
          child: Scaffold(body: TextField(focusNode: focusNode)),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    // Keyboard shows: nonzero bottom inset. Focus must be retained.
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    // Keyboard hides: inset returns to zero. Focus must be dropped.
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();

    expect(focusNode.hasFocus, isFalse);
  });
}
