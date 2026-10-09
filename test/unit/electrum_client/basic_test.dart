import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';
import 'package:electrum_adapter/electrum_adapter.dart';

import '../mock_electrum_server.dart';

void main() {
  late MockElectrumServer server;
  setUp(() => server = MockElectrumServer());

  group('ElectrumClient', () {
    late RavenElectrumClient client;
    setUp(() => client = RavenElectrumClient(server.channel));

    test('gets server features', () async {
      server.willRespondWith('features', {
        'hosts': {},
        'pruning': null,
        'server_version': 'ElectrumX Ravencoin 1.9',
        'protocol_min': '1.4',
        'protocol_max': '1.9',
        'genesis_hash':
            '000000ecfc5e6324a079542221d00e10362bdc894d56500c414060eea8a3ad5a',
        'hash_function': 'sha256',
        'services': []
      });
      expect((await client.features())['genesis_hash'],
          '000000ecfc5e6324a079542221d00e10362bdc894d56500c414060eea8a3ad5a');
    });

    Future<Object?> versionRequest(
        Future<void> Function(RavenElectrumClient) call) async {
      var channel = StreamChannelController<dynamic>();
      var client = RavenElectrumClient(channel.local);
      var request = channel.foreign.stream.first;
      var done = call(client);
      var sent = await request as Map;
      channel.foreign.sink.add({
        'jsonrpc': '2.0',
        'id': sent['id'],
        'result': ['ElectrumX Ravencoin 1.9.3', '1.9'],
      });
      await done;
      return sent['params'];
    }

    test('asks for protocol 1.4 to 1.10 by default', () async {
      expect(await versionRequest((client) => client.serverVersion()), [
        'RavenElectrumClient',
        ['1.4', '1.10']
      ]);
    });

    test('can ask for one protocol version', () async {
      expect(
        await versionRequest(
          (client) => client.serverVersion(minProtocolVersion: null),
        ),
        ['RavenElectrumClient', '1.10'],
      );
      expect(
        await versionRequest(
          (client) => client.serverVersion(protocolVersion: '1.4'),
        ),
        ['RavenElectrumClient', '1.4'],
      );
    });
  });
}
