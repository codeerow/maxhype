import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'screens/main_scaffold.dart';
import 'core/service_locator.dart';
import 'core/bloc_factory.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize dependency injection
  await setupDependencies();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Provider<BlocFactory>(
      create: (_) => BlocFactory(getIt: getIt),
      child: MaterialApp(
        title: 'MaxHype',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const MainScaffold(),
      ),
    );
  }
}
