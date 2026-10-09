import '../../electrum_adapter.dart';

class ServerVersion {
  String name;
  String protocol;
  ServerVersion(this.name, this.protocol);
}

extension ServerVersionMethod on RavenElectrumClient {
  Future<ServerVersion> serverVersion({
    String clientName = 'RavenElectrumClient',
    String? minProtocolVersion = '1.4',
    String protocolVersion = '1.10',
  }) async {
    var proc = 'server.version';
    var version =
        minProtocolVersion == null || minProtocolVersion == protocolVersion
            ? protocolVersion
            : [minProtocolVersion, protocolVersion];
    var response = await request(proc, [clientName, version]);
    return ServerVersion(response[0], response[1]);
  }
}
