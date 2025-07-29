import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'pdf_web_version.dart';
import 'pdf_mobile_version.dart';

class PdfSignerPage extends StatelessWidget {
  const PdfSignerPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Web ise web versiyonu, değilse mobil versiyonu göster
    if (kIsWeb) {
      return PdfWebVersion();
    } else {
      return PdfMobileVersion();
    }
  }
}
