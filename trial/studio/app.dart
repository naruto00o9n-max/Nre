import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'library_store.dart';
import 'library_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final library = await LibraryStore.open();
    runApp(StudioApp(library: library));
  } catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('تعذر فتح المعرض. ملفاتك لم تُحذف.\n$error'),
          ),
        ),
      ),
    );
  }
}

class StudioApp extends StatelessWidget {
  const StudioApp({super.key, required this.library});
  final LibraryStore library;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'مرسم المانهوا',
    debugShowCheckedModeBanner: false,
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      fontFamily: 'NotoSansArabic',
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF101218),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF9FA8FF),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    ),
    builder: BotToastInit(),
    navigatorObservers: [BotToastNavigatorObserver()],
    home: StudioHome(library: library),
  );
}
