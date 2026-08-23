import 'package:flutter/material.dart';
import 'package:asko_pdf/pages/pdf_viewer_page.dart';
import 'package:asko_pdf/gelide/gelide_engine.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await GelideEngine.instance.initialize();
  } catch (e, st) {
    debugPrint('Gelide init failed: $e\n$st');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AskoPDF',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFE0E0E0),
      ),
      home: const PdfViewerPage(),
    );
  }
}
