import 'package:flutter/material.dart';

/// Corner radii tokens extracted from the Stitch "Velvet Daub" system.
class AppRadii {
  const AppRadii._();

  static const double sm = 4.0;
  static const double md = 8.0;
  static const double cell = 10.0;
  static const double lg = 12.0;
  static const double xl = 16.0;
  static const double xxl = 24.0;
  static const double full = 9999.0;

  // BorderRadius objects
  static const BorderRadius roundedSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius roundedMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius roundedCell = BorderRadius.all(
    Radius.circular(cell),
  );
  static const BorderRadius roundedLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius roundedXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius roundedXxl = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius roundedFull = BorderRadius.all(
    Radius.circular(full),
  );
}
