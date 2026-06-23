/// A 1-bit-per-pixel raster, already in PPLB `GW` form: bit 1 = white/blank,
/// bit 0 = black, each row padded to a whole byte.
abstract interface class Bitmap {
  /// Width of the image in pixels.
  int widthPixels();

  /// Height of the image in pixels (= number of raster rows).
  int heightPixels();

  /// Width of one raster row in bytes (`widthPixels` rounded up to a byte).
  int widthBytes();

  /// Packed raster bytes, `widthBytes() * heightPixels()` long.
  List<int> bits();
}

/// A [Bitmap] backed by literal dimensions and packed bytes.
class ConstBitmap implements Bitmap {
  const ConstBitmap({
    required int widthPixels,
    required int heightPixels,
    required List<int> bits,
  })  : _widthPixels = widthPixels,
        _heightPixels = heightPixels,
        _bits = bits;

  final int _widthPixels;
  final int _heightPixels;
  final List<int> _bits;

  @override
  int widthPixels() => _widthPixels;

  @override
  int heightPixels() => _heightPixels;

  @override
  int widthBytes() => (_widthPixels + 7) ~/ 8;

  @override
  List<int> bits() => _bits;
}
