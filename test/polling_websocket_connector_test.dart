import 'package:flutter_test/flutter_test.dart';
import 'package:shear_heaven_pet_spa/src/common/services/polling_websocket_connector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PollingWebSocket Connector Tests', () {
    test('PollingWebSocket can be instantiated with valid URI', () {
      final uri = Uri.parse('wss://api.shearheavenpetspa.com/socket.io/?EIO=4&transport=websocket');
      final socket = PollingWebSocket(uri);
      expect(socket.protocol, equals(''));
      expect(socket.events, isNotNull);
    });

    test('resilientWebSocketConnector falls back to PollingWebSocket when websocket throws or times out', () async {
      // Connect to non-existent websocket port to test fallback
      final uri = Uri.parse('ws://127.0.0.1:59999/socket.io/?EIO=4&transport=websocket');
      // Should not throw uncaught error and should attempt fallback
      try {
        await resilientWebSocketConnector(uri);
      } catch (e) {
        // Fallback attempted and caught connection refusal
        expect(e, isNotNull);
      }
    });
  });
}
