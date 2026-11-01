import 'package:flutter/material.dart';

import 'credentials.dart';
import 'desktop_bridge.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'snapshot_cache.dart';
import 'store.dart';
import 'widget_bridge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = ThaskStore(SecureCredentialStore(), cache: PrefsSnapshotCache());
  final bridge = WidgetBridge(store);
  await bridge.attach();
  await DesktopBridge(store).attach();
  runApp(ThaskApp(store: store, bridge: bridge));
}

class ThaskApp extends StatefulWidget {
  const ThaskApp({super.key, required this.store, this.bridge});

  final ThaskStore store;
  final WidgetBridge? bridge;

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
          return HomeScreen(store: widget.store, launch: widget.bridge?.launch);
        },
      ),
    );
  }
}
