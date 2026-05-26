import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home.dart';
import 'screens/deck_builder.dart';
import 'providers/nikke_provider.dart';
import 'providers/theme_provider.dart';

void main() {
  runApp(const MimirApp());
}

class MimirApp extends StatelessWidget {
  const MimirApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => NikkeProvider()..loadNikkes(), // 앱 시작 시 니케 목록 로딩
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider()..loadTheme(), // 테마 초기화 로드
        ),
      ],
      child: Builder(
        builder: (context) {
          final themeProvider = context.watch<ThemeProvider>();
          
          return MaterialApp(
            title: 'MIMIR - 니케 덱빌딩 도우미',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            
            // 💡 라이트 테마: 기존의 밝고 경쾌한 톤 유지 (오렌지/블랙 대비)
            theme: ThemeData(
              brightness: Brightness.light,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.orange,
                brightness: Brightness.light,
                primary: Colors.orange,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              useMaterial3: true,
            ),
            
            // 💡 다크 테마: 로딩 화면의 명품 조합(다크 백그라운드 #0D0E12 + 오렌지 액센트 #F77C00) 매칭
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.orange,
                brightness: Brightness.dark,
                primary: Colors.orange,
                surface: const Color(0xFF1E1E1E),
                onSurface: Colors.white,
              ),
              scaffoldBackgroundColor: const Color(0xFF121212),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF1E1E1E),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              useMaterial3: true,
            ),
            
            home: const HomeScreen(),
            routes: {
              DeckBuilderScreen.routeName: (context) => const DeckBuilderScreen(),
            },
          );
        },
      ),
    );
  }
}
