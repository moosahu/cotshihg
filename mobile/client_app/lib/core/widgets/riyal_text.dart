import 'package:flutter/material.dart';

/// Renders an amount followed by the official Saudi Riyal symbol.
/// Uses the SaudiRiyal font (U+E900) for the currency symbol.
class RiyalText extends StatelessWidget {
  final String amount;
  final TextStyle? style;

  const RiyalText(this.amount, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(style);
    return RichText(
      text: TextSpan(
        style: base,
        children: [
          TextSpan(text: '$amount '),
          TextSpan(
            text: '\uE900',
            style: TextStyle(
              fontFamily: 'SaudiRiyal',
              fontSize: (base.fontSize ?? 14) * 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
