import 'package:flutter/material.dart';

import 'credentials.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'store.dart';

void main() {
  runApp(ThaskApp(store: ThaskStore(SecureCredentialStore())));
}

class ThaskApp extends StatefulWidget {
  const ThaskApp({super.key, required this.store});

  final ThaskStore store;

  @override
  State<ThaskApp> createState() => _ThaskAppState();
}

class _ThaskAppState extends State<ThaskApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.store.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.store.resume();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'tHAsk',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: Colors.indigo, brightness: Brightness.dark, useMaterial3: true),
      home: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          if (!widget.store.loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          if (!widget.store.hasCredentials) return LoginScreen(store: widget.store);
          return HomeScreen(store: widget.store);
        },
      ),
    );
  }
}
