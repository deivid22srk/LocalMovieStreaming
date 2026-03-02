import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AppImage extends StatelessWidget {
  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? errorWidget;

  const AppImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) {
      return errorWidget ?? _defaultError();
    }

    if (path.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: path,
        fit: fit,
        width: width,
        height: height,
        placeholder: (context, url) => Container(color: Colors.grey.shade900),
        errorWidget: (context, url, error) => errorWidget ?? _defaultError(),
      );
    } else {
      return Image.file(
        File(path),
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) => errorWidget ?? _defaultError(),
      );
    }
  }

  Widget _defaultError() {
    return Container(
      color: Colors.grey.shade900,
      width: width,
      height: height,
      child: const Icon(Icons.broken_image, color: Colors.white24),
    );
  }
}
