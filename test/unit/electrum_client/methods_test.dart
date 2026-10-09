import 'package:test/test.dart';

import 'package:electrum_adapter/electrum_adapter.dart';

import '../mock_electrum_server.dart';

void main() {
  group('subscriptions', () {
    late MockElectrumServer server;
    late RavenElectrumClient client;
    setUp(() {
      server = MockElectrumServer();
      client = RavenElectrumClient(server.channel);
    });

    test('getBalance', () async {
      var method = 'blockchain.scripthash.get_balance';
      server.willRespondWith(method, {'confirmed': 1, 'unconfirmed': 0});
      var result = await client.getBalance('scripthash1');
      expect(result, ScripthashBalance(1, 0));
    });

    test('getHistory', () async {
      var method = 'blockchain.scripthash.get_history';
      server.willRespondWith(method, [
        {'height': 123, 'tx_hash': '00a1b2c3'},
        {'height': 124, 'tx_hash': '00010203'},
      ]);
      var results = await client.getHistory('scripthash1');
      expect(results, [
        ScripthashHistory(height: 123, txHash: '00a1b2c3'),
        ScripthashHistory(height: 124, txHash: '00010203')
      ]);
    });

    test('getUnspent', () async {
      var method = 'blockchain.scripthash.get_unspent';
      server.willRespondWith(
        method,
        [
          {'height': 123, 'tx_hash': '00a1b2c3', 'tx_pos': 1, 'value': 5}
        ],
      );
      var results = await client.getUnspent('scripthash1');
      expect(
        results,
        [
          ScripthashUnspent(
              scripthash: 'scripthash1',
              height: 123,
              txHash: '00a1b2c3',
              txPos: 1,
              value: 5)
        ],
      );
    });

    test('getMeta reads integer flags', () async {
      server.willRespondWith('blockchain.asset.get_meta', {
        'sats_in_circulation': 100,
        'divisions': 0,
        'reissuable': 1,
        'has_ipfs': 0,
        'source': {'tx_hash': '00a1b2c3', 'tx_pos': 3, 'height': 5},
      });

      expect(
        await client.getMeta('ASSET'),
        AssetMeta(
          symbol: 'ASSET',
          satsInCirculation: 100,
          divisions: 0,
          reissuable: true,
          hasIpfs: false,
          source: TxSource(txHash: '00a1b2c3', txPos: 3, height: 5),
        ),
      );
    });

    test('getMeta rejects a flag that is not 0 or 1', () async {
      server.willRespondWith('blockchain.asset.get_meta', {
        'sats_in_circulation': 100,
        'divisions': 0,
        'reissuable': 'yes',
        'has_ipfs': 0,
        'source': {'tx_hash': '00a1b2c3', 'tx_pos': 3, 'height': 5},
      });

      await expectLater(
        client.getMeta('ASSET'),
        throwsA(isA<FormatException>()),
      );
    });

    test('getTransaction accepts omitted confirmation fields', () async {
      server.willRespondWith('blockchain.transaction.get', {
        'txid': 'aa',
        'hash': 'bb',
        'version': 1,
        'size': 2,
        'vsize': 2,
        'locktime': 0,
        'hex': '00',
        'vin': [
          {'coinbase': '03', 'sequence': 4294967295}
        ],
        'vout': [
          {
            'value': 1.0,
            'n': 0,
            'valueSat': 100000000,
            'scriptPubKey': {
              'asm': 'OP_DUP',
              'hex': '76',
              'type': 'pubkeyhash',
              'reqSigs': 1,
              'addresses': ['RAddress'],
            },
          },
        ],
      });

      var tx = await client.getTransaction('aa');
      expect(tx.vin.single.coinbase, '03');
      expect(tx.vout.single.scriptPubKey.addresses, ['RAddress']);
      expect(tx.blockhash, isNull);
      expect(tx.confirmations, isNull);
    });

    test('getMemo reads a short memo from the script hex', () async {
      server.willRespondWith('blockchain.transaction.get', {
        'vout': [
          {
            'scriptPubKey': {'asm': 'OP_RETURN', 'hex': '6a'}
          },
          {
            'scriptPubKey': {'asm': 'OP_RETURN 26952', 'hex': '6a024869'}
          },
        ],
      });

      expect(await client.getMemo('aa'), '4869');
    });

    test('memoFromScript validates and decodes push opcodes', () {
      var commitment =
          'aa21a9ede2f61c3f71d1defd3fa999dfa36953755c690689799962b48bebd836974e8cf9';
      expect(memoFromScript('6a24$commitment'), commitment);
      expect(memoFromScript('6a'), '');
      expect(memoFromScript('6a00'), '');
      expect(memoFromScript('6a4c02beef'), 'beef');
      expect(memoFromScript('6a4d0200beef'), 'beef');
      expect(memoFromScript('6a4e02000000beef'), 'beef');
      expect(memoFromScript('6a4f'), '81');
      expect(memoFromScript('6a51'), '01');
      expect(memoFromScript('6a60'), '10');
      expect(memoFromScript('76a914'), isNull);
      expect(memoFromScript('6a50'), isNull);
      expect(memoFromScript('6a04beef'), isNull);
      expect(memoFromScript('6a0'), isNull);
      expect(memoFromScript('6azz'), isNull);
    });
  });
}
