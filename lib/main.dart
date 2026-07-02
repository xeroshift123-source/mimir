import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/home.dart';
import 'screens/deck_builder.dart';
import 'screens/union_deck_builder.dart';
import 'screens/deck_library.dart';
import 'screens/calculate_list.dart';
import 'screens/login.dart';
import 'screens/sync_screen.dart';
import 'screens/my_nikke_screen.dart';
import 'screens/overload_simulator_screen.dart';
import 'providers/nikke_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'utils/cp_calculator.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase initialization failed in main: $e");
  }
  await CpCalculator.init();
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
          create: (_) => ThemeProvider()..loadTheme(), // 테마 초기화 로f드
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(), // 사용자 인증 정보 상태 관리
        ),
      ],
      child: Builder(
        builder: (context) {
          final themeProvider = context.watch<ThemeProvider>();

          return MaterialApp(
            title: 'MIMIR - 니케 덱빌딩 도우미',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            shortcuts: {
              ...WidgetsApp.defaultShortcuts,
              const SingleActivator(LogicalKeyboardKey.space):
                  const DoNothingAndStopPropagationIntent(),
            },

            // 💡 라이트 테마: 기존의 밝고 경쾌한 톤 유지 (오렌지/블랙 대비)
            theme: ThemeData(
              brightness: Brightness.light,
              fontFamilyFallback: const [
                'Malgun Gothic',
                'Apple SD Gothic Neo',
                'Noto Sans CJK KR',
                'sans-serif'
              ],
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
              fontFamilyFallback: const [
                'Malgun Gothic',
                'Apple SD Gothic Neo',
                'Noto Sans CJK KR',
                'sans-serif'
              ],
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
              DeckBuilderScreen.routeName: (context) =>
                  const DeckBuilderScreen(),
              UnionDeckBuilderScreen.routeName: (context) =>
                  const UnionDeckBuilderScreen(),
              DeckLibraryScreen.routeName: (context) =>
                  const DeckLibraryScreen(),
              CalculateListScreen.routeName: (context) =>
                  const CalculateListScreen(),
              LoginScreen.routeName: (context) => const LoginScreen(),
              SyncScreen.routeName: (context) => const SyncScreen(),
              MyNikkeScreen.routeName: (context) => const MyNikkeScreen(),
              OverloadSimulatorScreen.routeName: (context) =>
                  const OverloadSimulatorScreen(),
            },
          );
        },
      ),
    );
  }
}
