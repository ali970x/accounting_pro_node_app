import "package:flutter/material.dart";

String phoneDisplay(String value) {
  return value.replaceAll(RegExp(r"\s+"), "");
}

class PhoneText extends StatelessWidget {
  final String value;
  final TextStyle? style;
  final TextAlign? textAlign;

  const PhoneText(this.value, {super.key, this.style, this.textAlign});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        phoneDisplay(value),
        textAlign: textAlign,
        style: style,
      ),
    );
  }
}
