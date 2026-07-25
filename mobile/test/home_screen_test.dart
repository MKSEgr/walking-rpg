import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/features/home/data/home_api_client.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/home/presentation/home_screen.dart';

void main() {
  testWidgets('home screen renders loaded backend snapshot', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          loader: () async => HomeSnapshot.demo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Сегодня: 0 / 6000'), findsOneWidget);
    expect(find.text('Навигатор'), findsOneWidget);
    expect(find.text('Искра'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('Доступная энергия: 0 · версия 0'), findsOneWidget);
  });

  testWidgets('home screen can retry after backend error', (
    WidgetTester tester,
  ) async {
    int attempts = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          loader: () async {
            attempts += 1;
            if (attempts == 1) {
              throw const HomeApiException(
                statusCode: 503,
                message: 'Backend недоступен',
              );
            }
            return HomeSnapshot.demo;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Не удалось загрузить состояние'), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('Сегодня: 0 / 6000'), findsOneWidget);
  });
}
