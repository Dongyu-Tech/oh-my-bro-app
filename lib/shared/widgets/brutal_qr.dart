import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:heymybro/shared/widgets/brutalism.dart';

/// A scannable QR code wearing the brutalist frame: hard border, optional hard
/// shadow, square modules in [BrutalColors.onBackground] on a light card.
///
/// The read side of QR in this app is `mobile_scanner` (`ScanPage`); this is
/// the write side. Keep the two payload formats in sync — see
/// `parseFriendPayload` in `scan_page.dart`.
///
/// [data] must not be empty: qr_flutter renders an error widget for an empty
/// payload, so callers gate on having something to encode first.
class BrutalQrCode extends StatelessWidget {
  const BrutalQrCode({
    super.key,
    required this.data,
    required this.size,
    this.radius = BrutalSpec.pillRadius,
    this.shadowOffset = 0,
  });

  /// The exact string the scanner will read back.
  final String data;

  /// Outer edge length, border included — the widget is always square.
  final double size;

  final double radius;
  final double shadowOffset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: brutalDecoration(
        color: BrutalColors.surface,
        radius: radius,
        offset: shadowOffset,
      ),
      // Quiet zone. A QR needs light margin around the modules or scanners
      // struggle to find the finder patterns against the border.
      padding: const EdgeInsets.all(10),
      child: QrImageView(
        data: data,
        padding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        gapless: true,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: BrutalColors.onBackground,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: BrutalColors.onBackground,
        ),
      ),
    );
  }
}
