import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:entwined_memories/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const EntwinedMemoriesApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
