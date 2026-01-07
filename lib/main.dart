import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home.dart';
import 'screens/deck_builder.dart';
import 'providers/nikke_provider.dart';

void main() {
  runApp(const MimirApp());
}

class MimirApp extends StatelessWidget {
  const MimirApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      // ✅ 여기서 앱 전체에 쓸 Provider들을 등록
      providers: [
        ChangeNotifierProvider(
          create: (_) => NikkeProvider()..loadNikkes(), // 앱 시작 시 니케 목록 로딩
        ),
      ],
      child: MaterialApp(
        title: 'mimir',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const HomeScreen(), // 첫 화면은 그대로 HomeScreen 유지
        routes: {
          DeckBuilderScreen.routeName: (context) => const DeckBuilderScreen(),
        },
      ),
    );
  }
}
