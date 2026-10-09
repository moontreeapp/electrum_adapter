import 'dart:io' as io;
import 'dart:convert' as convert;

import 'package:stream_channel/stream_channel.dart';
// ignore: implementation_imports
import 'package:json_rpc_2/src/utils.dart' as utils;

import 'client/json_newline_transformer.dart';

const connectionTimeout = Duration(seconds: 5);
const aliveTimerDuration = Duration(seconds: 2);

/// Opens a TLS connection to an Electrum server.
///
/// [acceptUnverified] opts out of certificate verification and should only be
/// used for a server reached over a trusted network. [securityContext] can
/// instead supply the trusted certificate for a self-signed server. When a
/// context is provided it is always enforced, even if [acceptUnverified] is
/// true.
Future<StreamChannel> connect(
  String host, {
  int port = 50002,
  Duration connectionTimeout = connectionTimeout,
  Duration aliveTimerDuration = aliveTimerDuration,
  bool acceptUnverified = false,
  io.SecurityContext? securityContext,
}) async {
  var socket = await io.SecureSocket.connect(host, port,
      timeout: connectionTimeout,
      context: securityContext,
      onBadCertificate:
          acceptUnverified && securityContext == null ? (_) => true : null);
  var channel = StreamChannel(socket.cast<List<int>>(), socket);
  var channelUtf8 =
      channel.transform(StreamChannelTransformer.fromCodec(convert.utf8));
  var channelJson = jsonNewlineDocument
      .bind(channelUtf8)
      .transformStream(utils.ignoreFormatExceptions);
  return channelJson;
}
