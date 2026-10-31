import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Fehler beim Anmelden oder bei einem Befehl.
class HaException implements Exception {
  HaException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class HaAuthException extends HaException {
  HaAuthException() : super('Das Zugriffstoken wurde abgelehnt.', code: 'auth_invalid');
}

/// Macht aus einer eingegebenen Adresse die WebSocket-URL von Home Assistant.
Uri websocketUri(String address) {
  var text = address.trim();
  if (text.isEmpty) throw HaException('Bitte die Adresse von Home Assistant eingeben.');
  if (!text.contains('://')) text = 'http://$text';
  final uri = Uri.parse(text);
  if (uri.host.isEmpty) throw HaException('Die Adresse ist ungültig.');
  final secure = uri.scheme == 'https' || uri.scheme == 'wss';
  final base = uri.path.endsWith('/') ? uri.path.substring(0, uri.path.length - 1) : uri.path;
  return Uri(scheme: secure ? 'wss' : 'ws', host: uri.host, port: uri.hasPort ? uri.port : null, path: '$base/api/websocket');
}

/// Was der Rest der App von einer Verbindung braucht; in Tests durch eine Attrappe ersetzbar.
abstract class HaConnection {
  Future<void> get closed;
  Future<dynamic> call(String type, [Map<String, dynamic> payload = const {}]);
  Stream<Map<String, dynamic>> subscribe(String type, [Map<String, dynamic> payload = const {}]);
  Future<void> close();
}

/// Verbindung zur WebSocket-API von Home Assistant mit Token-Anmeldung.
class HaClient implements HaConnection {
  HaClient._(this._socket);

  final WebSocket _socket;
  int _nextId = 1;
  final _pending = <int, Completer<dynamic>>{};
  final _subscriptions = <int, StreamController<Map<String, dynamic>>>{};
  final _closed = Completer<void>();

  /// Wird abgeschlossen, sobald die Verbindung beendet ist.
  @override
  Future<void> get closed => _closed.future;

  static Future<HaClient> connect(String address, String token, {Duration timeout = const Duration(seconds: 10)}) async {
    final uri = websocketUri(address);
    final WebSocket socket;
    try {
      socket = await WebSocket.connect(uri.toString()).timeout(timeout);
    } on TimeoutException {
      throw HaException('Home Assistant antwortet nicht.');
    } on SocketException catch (e) {
      throw HaException('Keine Verbindung: ${e.message}');
    } on WebSocketException catch (e) {
      throw HaException('Keine Verbindung: ${e.message}');
    }
    final client = HaClient._(socket);
    try {
      await client._authenticate(token).timeout(timeout);
    } on TimeoutException {
      await socket.close();
      throw HaException('Home Assistant antwortet nicht.');
    } catch (_) {
      await socket.close();
      rethrow;
    }
    return client;
  }

  Completer<void>? _auth;

  Future<void> _authenticate(String token) {
    final completer = _auth = Completer<void>();
    _token = token;
    _socket.listen(_onMessage, onDone: _onDone, onError: (Object _) => _onDone());
    return completer.future;
  }

  late final String _token;

  void _send(Map<String, dynamic> message) => _socket.add(jsonEncode(message));

  void _onMessage(dynamic raw) {
    final msg = jsonDecode(raw as String) as Map<String, dynamic>;
    final auth = _auth;
    if (auth != null && !auth.isCompleted) {
      switch (msg['type']) {
        case 'auth_required':
          _send({'type': 'auth', 'access_token': _token});
        case 'auth_ok':
          auth.complete();
        case 'auth_invalid':
          auth.completeError(HaAuthException());
      }
      return;
    }
    final id = msg['id'] as int?;
    if (id == null) return;
    switch (msg['type']) {
      case 'result':
        final completer = _pending.remove(id);
        if (completer == null) return;
        if (msg['success'] == true) {
          completer.complete(msg['result']);
        } else {
          final error = msg['error'] as Map<String, dynamic>?;
          completer.completeError(HaException(error?['message'] as String? ?? 'Unbekannter Fehler', code: error?['code'] as String?));
        }
      case 'event':
        _subscriptions[id]?.add(msg['event'] as Map<String, dynamic>);
    }
  }

  void _onDone() {
    final auth = _auth;
    if (auth != null && !auth.isCompleted) auth.completeError(HaException('Die Verbindung wurde beendet.'));
    for (final completer in _pending.values) {
      completer.completeError(HaException('Die Verbindung wurde beendet.'));
    }
    _pending.clear();
    for (final controller in _subscriptions.values) {
      controller.close();
    }
    _subscriptions.clear();
    if (!_closed.isCompleted) _closed.complete();
  }

  /// Sendet einen Befehl und wartet auf das Ergebnis.
  @override
  Future<dynamic> call(String type, [Map<String, dynamic> payload = const {}]) {
    final id = _nextId++;
    final completer = Completer<dynamic>();
    _pending[id] = completer;
    _send({'id': id, 'type': type, ...payload});
    return completer.future;
  }

  /// Abonniert einen Befehl und liefert dessen Ereignisse.
  @override
  Stream<Map<String, dynamic>> subscribe(String type, [Map<String, dynamic> payload = const {}]) {
    final id = _nextId++;
    final controller = StreamController<Map<String, dynamic>>();
    _subscriptions[id] = controller;
    final ack = Completer<dynamic>();
    _pending[id] = ack;
    _send({'id': id, 'type': type, ...payload});
    ack.future.catchError((Object e) {
      controller.addError(e);
      controller.close();
      return null;
    });
    return controller.stream;
  }

  @override
  Future<void> close() async {
    await _socket.close();
    _onDone();
  }
}
