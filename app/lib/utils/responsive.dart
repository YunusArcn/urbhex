import 'package:flutter/material.dart';

/// Cihaz sinifi: telefon / tablet / masaustu-web.
/// Gorunum degistikce ikon, yazi ve panel oranlari bu siniftan turetilir.
enum FormFactor { mobile, tablet, desktop }

FormFactor formFactorOf(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w < 600) return FormFactor.mobile;
  if (w < 1100) return FormFactor.tablet;
  return FormFactor.desktop;
}

extension FormFactorX on FormFactor {
  /// Ikon/rozet olcek katsayisi (buyuk ekranda oranlar buyur, bosa dusmez).
  double get scale => switch (this) {
        FormFactor.mobile => 1.0,
        FormFactor.tablet => 1.15,
        FormFactor.desktop => 1.3,
      };

  /// Olay paneli: telefonda alttan kayar, tablette genis alt panel,
  /// masaustunde sag yan panel.
  bool get sidePanel => this == FormFactor.desktop;

  double get sheetInitialSize => this == FormFactor.mobile ? 0.6 : 0.75;

  double get searchBarMaxWidth => switch (this) {
        FormFactor.mobile => double.infinity,
        FormFactor.tablet => 520,
        FormFactor.desktop => 620,
      };
}
