// Renders the logo and the app icon from the same painter the app draws
// with, so the icon can never drift from the mark:
//
//   flutter test test/tool/render_brand_test.dart
//   python3 tool/make_icons.py
//
// Writes assets/brand/icon_1024.png and assets/brand/mark.png.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:aloft/config/palette.dart';
import 'package:aloft/widgets/aloft_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _write(
  String path,
  double size,
  void Function(Canvas, Size) draw,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  draw(canvas, Size.square(size));
  final image = await recorder.endRecording().toImage(
    size.round(),
    size.round(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('renders the icon and the mark', () async {
    const p = Palette.light;
    await _write('assets/brand/icon_1024.png', 1024, (canvas, size) {
      final rect = Offset.zero & size;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            rect.topCenter,
            rect.bottomCenter,
            p.sky,
            const [0, .55, 1],
          ),
      );
      final glow = Offset(size.width * .7, size.height * .95);
      canvas.drawCircle(
        glow,
        size.width * .8,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.radial(glow, size.width * .8, [
            p.sun.withValues(alpha: .3),
            p.sun.withValues(alpha: 0),
          ]),
      );
      const inset = 112.0;
      canvas.translate(inset, inset);
      MarkPainter(
        palette: p,
        frame: p.cloud,
      ).paint(canvas, Size.square(size.width - inset * 2));
    });
    await _write('assets/brand/mark.png', 512, (canvas, size) {
      MarkPainter(palette: p, frame: p.ink).paint(canvas, size);
    });
    expect(File('assets/brand/icon_1024.png').existsSync(), isTrue);
  });
}
