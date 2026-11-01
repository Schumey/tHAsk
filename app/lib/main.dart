import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'credentials.dart';
import 'desktop_bridge.dart';
import 'home_screen.dart';
import 'l10n.dart';
import 'login_screen.dart';
import 'snapshot_cache.dart';
import 'store.dart';
import 'widget_bridge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  L10n.lang = L10n.resolve(WidgetsBinding.instance.platformDispatcher.locale.languageCode);
  final store = ThaskStore(SecureCredentialStore(), cache: PrefsSnapshotCache());
  final bridge = WidgetBridge(store);
  await bridge.attach();
  await DesktopBridge(store).attach();
  runApp(ThaskApp(store: store, bridge: bridge));
}

/// Blau des Standard-Themes von Home Assistant (primary-color); auch im Symbol, im Widget und im Zähler
/// der Taskleiste.
const haBlue = Color(0xFF03A9F4);

/// Farben aus dem HA-Blau. `fidelity` hält die Farbe näher am Original als die blassere Standard-Ableitung.
ThemeData thaskTheme(Brightness brightness) => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: haBlue,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      ),
    );

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
      locale: L10n.locale,
      supportedLocales: [for (final lang in L10n.languages) Locale(lang)],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: thaskTheme(Brightness.light),
      darkTheme: thaskTheme(Brightness.dark),
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
