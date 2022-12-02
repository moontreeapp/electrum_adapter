import '../../electrum_adapter.dart';

extension PingServerMethod on RavenElectrumClient {
  Future<dynamic> ping() async => request('server.ping');
}
