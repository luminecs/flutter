import 'package:flutter/material.dart';
import 'package:flutter_api_samples/material/toggle_buttons/toggle_buttons.0.dart' as example;
import 'package:flutter_test/flutter_test.dart';

void main() {

  testWidgets('Single-select ToggleButtons', (WidgetTester tester) async {
    TextButton findButton(String text) {
      return tester.widget<TextButton>(find.widgetWithText(TextButton, text));
    }
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: example.ToggleButtonsExampleApp(),
        ),
      ),
    );

    TextButton firstButton = findButton('Apple');
    TextButton secondButton = findButton('Banana');
    TextButton thirdButton = findButton('Orange');

    const Color selectedColor = Color(0xffef9a9a);
    const Color unselectedColor = Color(0x00fffbfe);

    expect(firstButton.style!.backgroundColor!.resolve(enabled), selectedColor);
    expect(secondButton.style!.backgroundColor!.resolve(enabled), unselectedColor);
    expect(thirdButton.style!.backgroundColor!.resolve(enabled), unselectedColor);

    await tester.tap(find.widgetWithText(TextButton, 'Banana'));
    await tester.pumpAndSettle();

    firstButton = findButton('Apple');
    secondButton = findButton('Banana');
    thirdButton = findButton('Orange');

    expect(firstButton.style!.backgroundColor!.resolve(enabled), unselectedColor);
    expect(secondButton.style!.backgroundColor!.resolve(enabled), selectedColor);
    expect(thirdButton.style!.backgroundColor!.resolve(enabled), unselectedColor);
  });

  testWidgets('Multi-select ToggleButtons', (WidgetTester tester) async {
    TextButton findButton(String text) {
      return tester.widget<TextButton>(find.widgetWithText(TextButton, text));
    }
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: example.ToggleButtonsExampleApp(),
        ),
      ),
    );

    TextButton firstButton = findButton('Tomatoes');
    TextButton secondButton = findButton('Potatoes');
    TextButton thirdButton = findButton('Carrots');

    const Color selectedColor = Color(0xffa5d6a7);
    const Color unselectedColor = Color(0x00fffbfe);

    expect(firstButton.style!.backgroundColor!.resolve(enabled), unselectedColor);
    expect(secondButton.style!.backgroundColor!.resolve(enabled), selectedColor);
    expect(thirdButton.style!.backgroundColor!.resolve(enabled), unselectedColor);

    await tester.tap(find.widgetWithText(TextButton, 'Tomatoes'));
    await tester.tap(find.widgetWithText(TextButton, 'Carrots'));
    await tester.pumpAndSettle();

    firstButton = findButton('Tomatoes');
    secondButton = findButton('Potatoes');
    thirdButton = findButton('Carrots');

    expect(firstButton.style!.backgroundColor!.resolve(enabled), selectedColor);
    expect(secondButton.style!.backgroundColor!.resolve(enabled), selectedColor);
    expect(thirdButton.style!.backgroundColor!.resolve(enabled), selectedColor);
  });

  testWidgets('Icon-only ToggleButtons', (WidgetTester tester) async {
    TextButton findButton(IconData iconData) {
      return tester.widget<TextButton>(find.widgetWithIcon(TextButton, iconData));
    }
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: example.ToggleButtonsExampleApp(),
        ),
      ),
    );

    TextButton firstButton = findButton(Icons.sunny);
    TextButton secondButton = findButton(Icons.cloud);
    TextButton thirdButton = findButton(Icons.ac_unit);

    const Color selectedColor =  Color(0xff90caf9);
    const Color unselectedColor = Color(0x00fffbfe);


    expect(firstButton.style!.backgroundColor!.resolve(enabled), unselectedColor);
    expect(secondButton.style!.backgroundColor!.resolve(enabled), unselectedColor);
    expect(thirdButton.style!.backgroundColor!.resolve(enabled), selectedColor);

    await tester.tap(find.widgetWithIcon(TextButton, Icons.sunny));
    await tester.pumpAndSettle();

    firstButton = findButton(Icons.sunny);
    secondButton = findButton(Icons.cloud);
    thirdButton = findButton(Icons.ac_unit);

    expect(firstButton.style!.backgroundColor!.resolve(enabled), selectedColor);
    expect(secondButton.style!.backgroundColor!.resolve(enabled), unselectedColor);
    expect(thirdButton.style!.backgroundColor!.resolve(enabled), unselectedColor);
  });
}

Set<MaterialState> enabled = <MaterialState>{ };