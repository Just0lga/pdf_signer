import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:signature/signature.dart';
import 'package:path_provider/path_provider.dart';

class PdfWebVersion extends StatefulWidget {
  @override
  _PdfWebVersionState createState() => _PdfWebVersionState();
}

class _PdfWebVersionState extends State<PdfWebVersion> {
  Uint8List? _pdfData;
  List<ui.Image> _pdfImages = [];
  Map<String, Uint8List> _signatures =
      {}; // pageIndex_sectionIndex -> signature
  SignatureController _signatureController = SignatureController();
  bool _isLoading = false;
  bool _isSaving = false;
  String? _selectedSignatureArea;
  String _savingProgress = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          'PDF İmzalama',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          if (_pdfData != null && !_isSaving)
            IconButton(icon: Icon(Icons.save), onPressed: _savePDF),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _pdfData == null && !_isLoading
          ? FloatingActionButton(
              onPressed: _pickPDF,
              child: Icon(Icons.upload_file, color: Colors.black),
              tooltip: 'PDF Yükle',
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading || _isSaving) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              _isLoading
                  ? 'PDF yükleniyor...'
                  : _savingProgress.isNotEmpty
                      ? _savingProgress
                      : 'PDF kaydediliyor...',
              style: TextStyle(fontSize: 16),
            ),
            if (_isSaving) ...[
              SizedBox(height: 8),
              Text(
                'Lütfen bekleyin, ekrana dokunmayın, işlem devam ediyor...',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      );
    }

    if (_pdfData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf, size: 64, color: Colors.blueAccent),
            SizedBox(height: 16),
            Text(
              'PDF dosyası seçin',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                _pickPDF();
              },
              child: Container(
                width: 200,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "PDF Yükle",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_selectedSignatureArea != null) _buildSignaturePanel(),
        Expanded(
          child: ListView.builder(
            itemCount: _pdfImages.length,
            itemBuilder: (context, pageIndex) {
              return _buildPDFPage(pageIndex);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSignaturePanel() {
    return Container(
      height: 200,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          Text(
            'İmza Alanı: $_selectedSignatureArea',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Signature(
                controller: _signatureController,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _clearSignature,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('Temizle', style: TextStyle(color: Colors.white)),
              ),
              ElevatedButton(
                onPressed: _saveSignature,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: Text('Kaydet', style: TextStyle(color: Colors.white)),
              ),
              ElevatedButton(onPressed: _cancelSignature, child: Text('İptal')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPDFPage(int pageIndex) {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Text(
                  'Sayfa ${pageIndex + 1}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Spacer(),
                Text(
                  'İmzalar: ${_getSignatureCountForPage(pageIndex)}/4',
                  style: TextStyle(color: Colors.blue),
                ),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final image = _pdfImages[pageIndex];
              final imageAspectRatio = image.width / image.height;
              final containerWidth = constraints.maxWidth;
              final containerHeight = containerWidth / imageAspectRatio;

              return Container(
                width: containerWidth,
                height: containerHeight,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: RawImage(image: image, fit: BoxFit.contain),
                    ),
                    _buildSignatureOverlay(
                      pageIndex,
                      containerWidth,
                      containerHeight,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureOverlay(
    int pageIndex,
    double containerWidth,
    double containerHeight,
  ) {
    final signatureAreaHeight = containerHeight * 0.2;
    final sectionWidth = containerWidth / 4;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: signatureAreaHeight,
      child: Row(
        children: List.generate(4, (sectionIndex) {
          String areaKey = '${pageIndex}_$sectionIndex';
          bool hasSignature = _signatures.containsKey(areaKey);

          return Expanded(
            child: GestureDetector(
              onTap: () => _selectSignatureArea(areaKey),
              child: Container(
                margin: EdgeInsets.all(2),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: hasSignature ? Colors.green : Colors.red,
                    width: 2,
                  ),
                  color: hasSignature
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                ),
                child: Stack(
                  children: [
                    if (hasSignature)
                      Positioned.fill(
                        child: Container(
                          padding: EdgeInsets.all(4),
                          child: Image.memory(
                            _signatures[areaKey]!,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    if (!hasSignature)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.edit, color: Colors.red, size: 24),
                            SizedBox(height: 4),
                            Text(
                              'İmza ${sectionIndex + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (hasSignature)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  int _getSignatureCountForPage(int pageIndex) {
    int count = 0;
    for (int i = 0; i < 4; i++) {
      if (_signatures.containsKey('${pageIndex}_$i')) {
        count++;
      }
    }
    return count;
  }

  Future<void> _pickPDF() async {
    try {
      setState(() => _isLoading = true);

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        Uint8List fileBytes;

        if (kIsWeb) {
          fileBytes = result.files.first.bytes!;
        } else {
          File file = File(result.files.single.path!);
          fileBytes = await file.readAsBytes();
        }

        setState(() {
          _pdfData = fileBytes;
          _signatures.clear();
        });

        await _convertPDFToImages();
      }
    } catch (e) {
      _showError('PDF yükleme hatası: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _convertPDFToImages() async {
    try {
      _pdfImages.clear();

      await for (var page in Printing.raster(_pdfData!, dpi: 150)) {
        final image = await page.toImage();
        _pdfImages.add(image);
      }

      setState(() {});
    } catch (e) {
      _showError('PDF görüntü çevirme hatası: $e');
    }
  }

  void _selectSignatureArea(String areaKey) {
    setState(() {
      _selectedSignatureArea = areaKey;
      _signatureController.clear();
    });
  }

  void _clearSignature() {
    _signatureController.clear();

    if (_selectedSignatureArea != null &&
        _signatures.containsKey(_selectedSignatureArea)) {
      setState(() {
        _signatures.remove(_selectedSignatureArea);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('İmza temizlendi'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _saveSignature() async {
    if (_selectedSignatureArea == null) return;

    try {
      final signature = await _signatureController.toPngBytes();
      if (signature != null && signature.isNotEmpty) {
        setState(() {
          _signatures[_selectedSignatureArea!] = signature;
          _selectedSignatureArea = null;
        });
        _signatureController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'İmza kaydedildi! Toplam: ${_signatures.length} imza',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _showError('Lütfen önce imza çizin');
      }
    } catch (e) {
      _showError('İmza kaydetme hatası: $e');
    }
  }

  void _cancelSignature() {
    setState(() {
      _selectedSignatureArea = null;
    });
    _signatureController.clear();
  }

  Future<void> _savePDF() async {
    if (_pdfData == null) return;

    setState(() {
      _isSaving = true;
      _savingProgress = "PDF işlemi başlatılıyor...";
    });

    try {
      // Küçük delay ile UI'ın güncellenmesini sağla
      await Future.delayed(Duration(milliseconds: 100));

      setState(() {
        _savingProgress = "Görüntüler hazırlanıyor...";
      });

      // Görüntüleri byte array'e çevir (arka planda)
      List<Uint8List> imageBytesList = [];
      for (int i = 0; i < _pdfImages.length; i++) {
        setState(() {
          _savingProgress = "Görüntü işleniyor: ${i + 1}/${_pdfImages.length}";
        });
        await Future.delayed(
          Duration(milliseconds: 50),
        ); // UI güncelleme zamanı

        final imageBytes = await _getImageBytes(_pdfImages[i]);
        imageBytesList.add(imageBytes);
      }

      setState(() {
        _savingProgress = "PDF oluşturuluyor...";
      });
      await Future.delayed(Duration(milliseconds: 100));

      // PDF oluşturma işlemini chunklara böl
      final pdf = pw.Document();

      for (int pageIndex = 0; pageIndex < _pdfImages.length; pageIndex++) {
        setState(() {
          _savingProgress =
              "PDF sayfası oluşturuluyor: ${pageIndex + 1}/${_pdfImages.length}";
        });
        await Future.delayed(Duration(milliseconds: 50));

        final pageImage = pw.MemoryImage(imageBytesList[pageIndex]);

        // Sayfa boyutları
        const pageFormat = PdfPageFormat.a4;
        final pageWidth = pageFormat.width;
        final pageHeight = pageFormat.height;

        // İmzaları topla
        List<pw.Widget> signatureWidgets = [];

        for (int sectionIndex = 0; sectionIndex < 4; sectionIndex++) {
          String areaKey = '${pageIndex}_$sectionIndex';

          if (_signatures.containsKey(areaKey)) {
            // İmza pozisyonunu hesapla
            final sectionWidth = pageWidth / 5;
            final signatureHeight = pageHeight * 0.15;

            final leftPosition = sectionIndex * sectionWidth + 10;
            final bottomPosition = 20.0;
            final width = sectionWidth - 20;
            final height = signatureHeight - 10;

            signatureWidgets.add(
              pw.Positioned(
                left: leftPosition,
                bottom: bottomPosition,
                child: pw.Container(
                  width: width,
                  height: height,
                  decoration: pw.BoxDecoration(),
                  padding: const pw.EdgeInsets.all(2),
                  child: pw.Image(
                    pw.MemoryImage(_signatures[areaKey]!),
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ),
            );
          }
        }

        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            build: (pw.Context context) {
              return pw.Stack(
                children: [
                  pw.Positioned.fill(
                    child: pw.Image(pageImage, fit: pw.BoxFit.contain),
                  ),
                  ...signatureWidgets,
                ],
              );
            },
          ),
        );
      }

      setState(() {
        _savingProgress = "PDF kaydediliyor...";
      });
      await Future.delayed(Duration(milliseconds: 100));

      final pdfBytes = await pdf.save();

      setState(() {
        _savingProgress = "Dosya sisteme kaydediliyor...";
      });
      await Future.delayed(Duration(milliseconds: 100));

      if (kIsWeb) {
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename:
              'imzali_dokuman_${DateTime.now().millisecondsSinceEpoch}.pdf',
        );
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final fileName =
            'imzali_dokuman_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(pdfBytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'PDF başarıyla kaydedildi!\n${_signatures.length} imza eklendi',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );

        await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
      }
    } catch (e) {
      _showError('PDF kaydetme hatası: $e');
    } finally {
      setState(() {
        _isSaving = false;
        _savingProgress = "";
      });
    }
  }

  Future<Uint8List> _getImageBytes(ui.Image image) async {
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return byteData!.buffer.asUint8List();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }
}
