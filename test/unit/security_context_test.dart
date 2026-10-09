import 'dart:convert';
import 'dart:io';

import 'package:electrum_adapter/electrum_adapter.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

const _reply = {
  'jsonrpc': '2.0',
  'id': 0,
  'result': ['ElectrumX Ravencoin', '1.9'],
};

void main() {
  if (!_hasOpenssl()) {
    test('TLS with a self-signed certificate', () {},
        skip: 'needs openssl on PATH');
    return;
  }

  Directory? dir;
  SecureServerSocket? bound;
  late String certPath;
  late SecureServerSocket server;

  setUpAll(() async {
    var tmp = dir = await Directory.systemTemp.createTemp('electrum_adapter');
    certPath = '${tmp.path}/cert.pem';
    var keyPath = '${tmp.path}/key.pem';
    var result = await Process.run('openssl', [
      'req',
      '-x509',
      '-newkey',
      'ec',
      '-pkeyopt',
      'ec_paramgen_curve:P-256',
      '-pkeyopt',
      'ec_param_enc:named_curve',
      '-nodes',
      '-keyout',
      keyPath,
      '-out',
      certPath,
      '-days',
      '1',
      '-subj',
      '/CN=localhost',
      '-addext',
      'subjectAltName=DNS:localhost',
      '-addext',
      'extendedKeyUsage=serverAuth',
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    server = bound = await SecureServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
      SecurityContext()
        ..useCertificateChain(certPath)
        ..usePrivateKey(keyPath),
    );
    server.listen((client) {
      client
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (_) => client.write('${jsonEncode(_reply)}\n'),
            onError: (_) {},
          );
    }, onError: (_) {});
  });

  tearDownAll(() async {
    await bound?.close();
    await dir?.delete(recursive: true);
  });

  SecurityContext trusting() => SecurityContext(withTrustedRoots: false)
    ..setTrustedCertificates(certPath);

  Future<Object?> roundTrip(Future<StreamChannel> connecting) async {
    var channel = await connecting;
    channel.sink.add({'jsonrpc': '2.0', 'id': 0, 'method': 'server.version'});
    var reply = await channel.stream.first.timeout(const Duration(seconds: 5));
    await channel.sink.close();
    return reply;
  }

  test('rejects an unverified certificate by default', () async {
    await expectLater(
      connect('localhost', port: server.port),
      throwsA(isA<HandshakeException>()),
    );
  });

  test('can explicitly accept an unverified certificate', () async {
    expect(
      await roundTrip(connect(
        'localhost',
        port: server.port,
        acceptUnverified: true,
      )),
      _reply,
    );
  });

  test('trusts a self-signed certificate from the context', () async {
    expect(
      await roundTrip(connect(
        'localhost',
        port: server.port,
        securityContext: trusting(),
      )),
      _reply,
    );
  });

  test('enforces a context even when acceptUnverified is true', () async {
    await expectLater(
      connect(
        'localhost',
        port: server.port,
        acceptUnverified: true,
        securityContext: SecurityContext(withTrustedRoots: false),
      ),
      throwsA(isA<HandshakeException>()),
    );
  });

  test('RavenElectrumClient passes the context through', () async {
    var client = await RavenElectrumClient.connect(
      'localhost',
      port: server.port,
      securityContext: trusting(),
    );
    addTearDown(client.close);
    expect(client.protocolVersion, '1.10');
  });
}

bool _hasOpenssl() {
  try {
    return Process.runSync('openssl', ['version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}
