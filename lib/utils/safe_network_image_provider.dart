import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;

/// Loads a small remote image without the extra uncaught exception produced by
/// Flutter 3.19's web NetworkImage implementation for non-2xx responses.
@immutable
class SafeNetworkImageProvider extends ImageProvider<SafeNetworkImageProvider> {
  const SafeNetworkImageProvider(this.url, {this.scale = 1.0});

  final String url;
  final double scale;

  @override
  Future<SafeNetworkImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<SafeNetworkImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    SafeNetworkImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: key.scale,
      debugLabel: key.url,
    );
  }

  Future<ui.Codec> _loadAsync(
    SafeNetworkImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    final uri = Uri.parse(key.url);
    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw NetworkImageLoadException(
        statusCode: response.statusCode,
        uri: uri,
      );
    }
    if (response.bodyBytes.isEmpty) {
      throw StateError('Remote image response was empty: $uri');
    }

    final buffer = await ui.ImmutableBuffer.fromUint8List(response.bodyBytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) {
    return other is SafeNetworkImageProvider &&
        other.url == url &&
        other.scale == scale;
  }

  @override
  int get hashCode => Object.hash(url, scale);
}
