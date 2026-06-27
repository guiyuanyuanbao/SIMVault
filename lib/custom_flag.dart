import 'package:flutter/material.dart';
import 'package:flag/flag.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CustomFlag extends StatelessWidget {
  final String isoCode;
  final double height;
  final double width;
  final double borderRadius;

  const CustomFlag({
    super.key,
    required this.isoCode,
    this.height = 16,
    this.width = 24,
    this.borderRadius = 2,
  });

  @override
  Widget build(BuildContext context) {
    if (isoCode.toUpperCase() == 'TW') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          color: Colors.white,
          height: height,
          width: width,
          child: SvgPicture.asset(
            'assets/Flag_of_Chinese_Taipei_for_Olympic_Games.svg',
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    return Flag.fromString(
      isoCode,
      height: height,
      width: width,
      borderRadius: borderRadius,
    );
  }
}
