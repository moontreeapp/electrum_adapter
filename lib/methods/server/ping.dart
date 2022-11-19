import '../../electrum_adapter.dart';

extension PingServerMethod on RavenElectrumClient {
  Future<dynamic> ping() async => await request('server.ping');
}
