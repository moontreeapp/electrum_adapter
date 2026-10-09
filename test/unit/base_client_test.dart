import 'package:json_rpc_2/json_rpc_2.dart' as rpc;
import 'package:test/test.dart';
import 'package:electrum_adapter/client/base_client.dart';

import './mock_electrum_server.dart';

void main() {
  late MockElectrumServer server;
  setUp(() => server = MockElectrumServer());

  group('BaseClient', () {
    late BaseClient client;
    setUp(() => client = BaseClient(server.channel));

    test('makes a request', () async {
      server.willRespondWith('test', 'hello world');
      expect(await client.request('test'), 'hello world');
    });

    test('makes two requests', () async {
      server.willRespondWith('test', 'one');
      expect(await client.request('test'), 'one');

      server.willRespondWith('test', 'two');
      expect(await client.request('test'), 'two');
    });

    test('logs an unhandled RPC error', () {
      expect(
          () => client.handleError(
              rpc.RpcException(1, 'use server.version'), StackTrace.current),
          prints(contains('use server.version')));
    });
  });
}
