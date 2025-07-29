import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';
import 'dart:io';

class PdfMobileVersion extends StatefulWidget {
  const PdfMobileVersion({Key? key}) : super(key: key);

  @override
  State<PdfMobileVersion> createState() => _PdfMobileVersionState();
}

class _PdfMobileVersionState extends State<PdfMobileVersion> {
  final GlobalKey<SfSignaturePadState> _signatureKey = GlobalKey();
  final PdfViewerController _pdfViewerController = PdfViewerController();
  final String _pdfUrl =
      'https://www.adobe.com/support/products/enterprise/knowledgecenter/media/c4611_sample_explain.pdf';

  Future<void> _removeSignatureFromPage(int pageIndex) async {
    _targetPageAfterSigning = pageIndex;

    final currentPdfBytes = await _getCurrentPdfBytes();
    final document = PdfDocument(inputBytes: currentPdfBytes);

    if (pageIndex >= 0 && pageIndex < document.pages.count) {
      final page = document.pages[pageIndex];
      final graphics = page.graphics;

      // Beyaz dikdörtgen çizerek imzayı sil
      final paint = PdfSolidBrush(PdfColor(255, 255, 255));
      final rect = Rect.fromLTWH(
        _signatureX,
        _signatureY,
        _signatureWidth,
        _signatureHeight,
      );
      graphics.drawRectangle(brush: paint, bounds: rect);

      final bytes = await document.save();
      document.dispose();

      final output = await getApplicationDocumentsDirectory();
      final clearedFile = File('${output.path}/signed_temp_sample.pdf');
      await clearedFile.writeAsBytes(bytes);

      setState(() {
        _currentPdfFile = clearedFile;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sayfa ${pageIndex + 1} imzası silindi.'),
          duration: Duration(milliseconds: 50),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Geçersiz sayfa numarası.')));
    }
  }

  File? _currentPdfFile;
  int _currentPageIndex = 0;
  int? _targetPageAfterSigning;
  int _totalPages = 0;

  final double _signatureWidth = 75;
  final double _signatureHeight = 50;
  final double _signatureX = 445;
  final double _signatureY = 717;

  @override
  void initState() {
    super.initState();
    _initializePdf();
  }

  Future<void> _initializePdf() async {
    final output = await getApplicationDocumentsDirectory();
    final initialFile = File('${output.path}/temp_sample.pdf');

    final httpClient = HttpClient();
    final request = await httpClient.getUrl(Uri.parse(_pdfUrl));
    final response = await request.close();
    final bytes = await consolidateHttpClientResponseBytes(response);

    await initialFile.writeAsBytes(bytes);

    setState(() {
      _currentPdfFile = initialFile;
    });
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        title: const Text(
          "PDF İmzalayıcı",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _shareSignedPdf,
          ),
        ],
      ),
      body: _currentPdfFile == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SfPdfViewer.file(
                  _currentPdfFile!,
                  controller: _pdfViewerController,
                  onPageChanged: (PdfPageChangedDetails details) {
                    setState(() {
                      _currentPageIndex = details.newPageNumber - 1;
                    });
                  },
                  onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                    setState(() {
                      _totalPages = details.document.pages.count;
                    });

                    if (_targetPageAfterSigning != null) {
                      Future.delayed(const Duration(milliseconds: 100), () {
                        _pdfViewerController.jumpToPage(
                          _targetPageAfterSigning! + 1,
                        );
                        _targetPageAfterSigning = null;
                      });
                    }
                  },
                ),
                if (_totalPages > 0)
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: width * 0.43,
                          height: height * 0.1,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 20,
                              ),
                            ),
                            onPressed: () =>
                                _showSignaturePad(_currentPageIndex),
                            child: Text(
                              '${_currentPageIndex + 1}. Sayfaya İmza Ekle',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: width * 0.43,
                          height: height * 0.1,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 20,
                              ),
                            ),
                            onPressed: () => _removeSignatureFromPage(
                              _currentPageIndex,
                            ),
                            child: const Text(
                              'İmzayı Temizle',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  void _showSignaturePad(int pageIndex) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Sayfa ${pageIndex + 1} için İmzanızı Çizin',
          textAlign: TextAlign.center,
        ),
        content: SizedBox(
          height: 200,
          width: 300,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SfSignaturePad(
              key: _signatureKey,
              backgroundColor: Colors.transparent,
              strokeColor: Colors.black,
              minimumStrokeWidth: 1.0,
              maximumStrokeWidth: 4.0,
            ),
          ),
        ),
        actions: [
          TextButton(
            child: const Text(
              'Temizle',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () => _signatureKey.currentState?.clear(),
          ),
          TextButton(
            child: const Text(
              'İptal',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text(
              'Onayla',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () async {
              final image = await _signatureKey.currentState!.toImage();
              final bytes = await _imageToBytes(image);
              await _embedSignatureToPage(pageIndex, bytes);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<Uint8List> _imageToBytes(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _embedSignatureToPage(
    int pageIndex,
    Uint8List signatureBytes,
  ) async {
    _targetPageAfterSigning = pageIndex;

    final currentPdfBytes = await _getCurrentPdfBytes();
    final document = PdfDocument(inputBytes: currentPdfBytes);

    final image = PdfBitmap(signatureBytes);

    if (pageIndex >= 0 && pageIndex < document.pages.count) {
      final page = document.pages[pageIndex];
      final graphics = page.graphics;

      final rect = Rect.fromLTWH(
        _signatureX,
        _signatureY,
        _signatureWidth,
        _signatureHeight,
      );

      graphics.drawImage(image, rect);

      final bytes = await document.save();
      document.dispose();

      final output = await getApplicationDocumentsDirectory();
      final signedFile = File('${output.path}/signed_temp_sample.pdf');
      await signedFile.writeAsBytes(bytes);

      setState(() {
        _currentPdfFile = signedFile;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sayfa ${pageIndex + 1} imzalandı.'),
          duration: Duration(milliseconds: 50),
        ),
      );
    } else {
      _targetPageAfterSigning = null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Geçersiz sayfa numarası.')));
    }
  }

  Future<Uint8List> _getCurrentPdfBytes() async {
    return await _currentPdfFile!.readAsBytes();
  }

  Future<void> _shareSignedPdf() async {
    if (_currentPdfFile != null && await _currentPdfFile!.exists()) {
      await Share.shareXFiles([
        XFile(_currentPdfFile!.path),
      ], text: 'İmzalı PDF');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF bulunamadı, önce imzalayın.')),
      );
    }
  }
}
