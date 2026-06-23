import 'dart:convert';
import 'package:pplb/pplb.dart';
import 'bitmap.dart';

/// PPLB `GW` — prints an immediate (one-shot) 1-bpp graphic.
///
/// `GWx,y,widthBytes,heightPixels,<raster bytes>` then LF. The image is
/// cleared by the printer after printing and cannot be recalled.
class ImmediateGraphic implements Command {
  const ImmediateGraphic({
    required this.x,
    required this.y,
    required this.bitmap,
  });

  /// X origin in dots.
  final int x;

  /// Y origin in dots.
  final int y;

  /// The raster to print.
  final Bitmap bitmap;

  @override
  List<int> bytes() => [
        ...ascii.encode(
          'GW$x,$y,${bitmap.widthBytes()},${bitmap.heightPixels()},',
        ),
        ...bitmap.bits(),
        ...ascii.encode('\n'),
      ];
}
