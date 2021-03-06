// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')

import 'dart:io';

import 'package:test/test.dart';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  var server;
  tearDown(() async {
    if (server != null) await server.close();
  });

  test("communicates using existing WebSockets", () async {
    server = await HttpServer.bind("localhost", 0);
    server.transform(new WebSocketTransformer()).listen((webSocket) {
      var channel = new IOWebSocketChannel(webSocket);
      channel.sink.add("hello!");
      channel.stream.listen((request) {
        expect(request, equals("ping"));
        channel.sink.add("pong");
        channel.sink.close(5678, "raisin");
      });
    });

    var webSocket = await WebSocket.connect("ws://localhost:${server.port}");
    var channel = new IOWebSocketChannel(webSocket);

    var n = 0;
    channel.stream.listen((message) {
      if (n == 0) {
        expect(message, equals("hello!"));
        channel.sink.add("ping");
      } else if (n == 1) {
        expect(message, equals("pong"));
      } else {
        fail("Only expected two messages.");
      }
      n++;
    }, onDone: expectAsync(() {
      expect(channel.closeCode, equals(5678));
      expect(channel.closeReason, equals("raisin"));
    }));
  });

  test(".connect communicates immediately", () async {
    server = await HttpServer.bind("localhost", 0);
    server.transform(new WebSocketTransformer()).listen((webSocket) {
      var channel = new IOWebSocketChannel(webSocket);
      channel.stream.listen((request) {
        expect(request, equals("ping"));
        channel.sink.add("pong");
      });
    });

    var channel = new IOWebSocketChannel.connect(
        "ws://localhost:${server.port}");
    channel.sink.add("ping");

    channel.stream.listen(expectAsync((message) {
      expect(message, equals("pong"));
      channel.sink.close(5678, "raisin");
    }, count: 1), onDone: expectAsync(() {}));
  });

  test(".connect with an immediate call to close", () async {
    server = await HttpServer.bind("localhost", 0);
    server.transform(new WebSocketTransformer()).listen((webSocket) {
      expect(() async {
        var channel = new IOWebSocketChannel(webSocket);
        await channel.stream.listen(null).asFuture();
        expect(channel.closeCode, equals(5678));
        expect(channel.closeReason, equals("raisin"));
      }(), completes);
    });

    var channel = new IOWebSocketChannel.connect(
        "ws://localhost:${server.port}");
    channel.sink.close(5678, "raisin");
  });

  test(".connect wraps a connection error in WebSocketChannelException",
      () async {
    server = await HttpServer.bind("localhost", 0);
    server.listen((request) {
      request.response.statusCode = 404;
      request.response.close();
    });

    var channel = new IOWebSocketChannel.connect(
        "ws://localhost:${server.port}");
    expect(channel.stream.toList(),
        throwsA(new isInstanceOf<WebSocketChannelException>()));
  });
}
