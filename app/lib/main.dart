import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gradecalculator/components/mainscaffold.dart';
import 'package:gradecalculator/providers/course_provider.dart';
import 'package:provider/provider.dart';
import 'package:gradecalculator/providers/auth_provider.dart';
import 'package:gradecalculator/screens/auth_screens/starting_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:gradecalculator/utils/app_text_styles.dart';
import 'package:gradecalculator/services/connectivity_service.dart';
import 'package:gradecalculator/services/offline_queue_service.dart';
import 'package:gradecalculator/services/local_storage_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Hive for local storage (OFFLINE-FIRST)
  print('📦 Initializing local storage...');
  final localStorage = LocalStorageService();
  await localStorage.initialize();
  print('✅ Local storage initialized');

  // Initialize connectivity service
  final connectivityService = ConnectivityService();
  await connectivityService.checkConnection();

  // Initialize cached text styles for better performance
  await AppTextStyles.initialize();

  // make the orientation portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // set the system UI overlay style to transparent
  // this will make the status bar and navigation bar transparent

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // initialize firebase (check if already initialized to prevent hot restart errors)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase already initialized, which happens during hot restart
    if (e.toString().contains('duplicate-app')) {
      // This is expected during hot restart, safe to ignore
    } else {
      rethrow;
    }
  }

  // Configure Firebase Firestore persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  // Initialize offline queue service (triggers auto-sync if online)
  OfflineQueueService(); // Initialize singleton

  // Display initialization summary
  final storageStats = localStorage.getStorageStats();
  print('═══════════════════════════════════════');
  print('🚀 GradesKo App Initialized');
  print('═══════════════════════════════════════');
  print(
    '📡 Connectivity: ${connectivityService.isOnline ? "Online ✅" : "Offline 📴"}',
  );
  print('📦 Local Storage Stats:');
  print('   • Courses: ${storageStats['courses']}');
  print('   • Components: ${storageStats['components']}');
  print('   • Records: ${storageStats['records']}');
  print('   • Queued Operations: ${storageStats['queuedOperations']}');
  print('═══════════════════════════════════════');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: connectivityService),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CourseProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Grade Calculator',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF121212)),
        textTheme: GoogleFonts.poppinsTextTheme(),
        // Input decoration theme to optimize text fields globally
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 12,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          if (authProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (authProvider.appUser != null) {
            return MainScaffold();
          } else {
            return StartingPage();
          }
        },
      ),
    );
  }
}
