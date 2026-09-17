import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/data/raid_data.dart';
import 'package:mimir/providers/auth_provider.dart';
import 'package:mimir/providers/theme_provider.dart';
import 'package:mimir/screens/home.dart';
import 'package:provider/provider.dart';

class _SignedOutAuth extends ChangeNotifier implements AuthProvider {
  @override
  bool get isLoggedIn => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Use Flutter's bundled font: Ahem's square glyphs overstate date widths.
    final config = File('.dart_tool/package_config.json').absolute;
    final packages =
        jsonDecode(await config.readAsString())['packages'] as List;
    final flutter =
        packages.singleWhere((package) => package['name'] == 'flutter');
    final flutterRoot =
        Directory.fromUri(config.uri.resolve(flutter['rootUri'] as String));
    final fontUri = flutterRoot.uri.resolve(
      '../../bin/cache/artifacts/material_fonts/roboto-regular.ttf',
    );
    final bytes = await File.fromUri(fontUri).readAsBytes();
    await (FontLoader('Roboto')
          ..addFont(Future.value(ByteData.sublistView(bytes))))
        .load();
  });
  for (final width in [360.0, 640.0, 1440.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('Home renders every raid at $width in $brightness',
          (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(
                create: (_) => _SignedOutAuth()),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ],
          child: MaterialApp(
            theme: ThemeData(brightness: brightness, fontFamily: 'Roboto'),
            home: const HomeScreen(),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.text(raidHistory.last.bossName!), findsOneWidget);
        expect(tester.takeException(), isNull);

        final pager = find.byType(PageView);
        final controller = tester.widget<PageView>(pager).controller;
        final pageWidth = tester.getSize(pager).width;
        final gesture = await tester.startGesture(
          tester.getTopLeft(pager) + Offset(pageWidth * .2, 60),
        );
        await gesture.moveBy(const Offset(24, 0));
        await tester.pump();
        await gesture.moveBy(Offset(pageWidth * .6, 0));
        await tester.pump();
        // The page must follow the finger before it is released.
        expect(controller.page, lessThan(raidHistory.length - 1));
        expect(controller.page, greaterThan(raidHistory.length - 2));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(controller.page, closeTo(raidHistory.length - 2, .001));

        await tester.dragFrom(
          tester.getTopLeft(pager) + Offset(pageWidth * .8, 60),
          Offset(-pageWidth * .6, 0),
        );
        await tester.pumpAndSettle();
        expect(controller.page, closeTo(raidHistory.length - 1, .001));
        expect(tester.takeException(), isNull);

        for (var index = raidHistory.length - 2; index >= 0; index--) {
          await tester.dragFrom(
            tester.getTopLeft(pager) + Offset(pageWidth * .2, 60),
            Offset(pageWidth * .6, 0),
          );
          await tester.pumpAndSettle();
          expect(find.text(raidHistory[index].seasonName), findsOneWidget);
          expect(tester.takeException(), isNull);
        }

        await tester.ensureVisible(find.text('내 니케 정보'));
        await tester.pumpAndSettle();
        expect(find.text('전투 정보 동기화'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
