import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';

/// Renders a receipt PDF fetched from `GET /student/fees/receipt/{id}`.
///
/// The bytes are passed in already downloaded rather than the viewer
/// being handed a URL. That is deliberate: the endpoint sits behind
/// `auth:sanctum`, so any loader that fetches the URL itself — a webview,
/// `PdfViewer.uri`, `url_launcher` — arrives without the bearer token and
/// receives a 302 to the web login page instead of a PDF.
class ReceiptViewerScreen extends StatefulWidget {
  final BinaryResponse receipt;
  final String title;

  const ReceiptViewerScreen({
    super.key,
    required this.receipt,
    this.title = 'Receipt',
  });

  @override
  State<ReceiptViewerScreen> createState() => _ReceiptViewerScreenState();
}

class _ReceiptViewerScreenState extends State<ReceiptViewerScreen> {
  bool _saving = false;

  /// Writes the PDF into the app's documents directory so the student has
  /// a copy outside the session.
  ///
  /// Kept separate from viewing on purpose — rendering works straight from
  /// memory, so nothing touches the filesystem unless the student asks.
  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final name = widget.receipt.safeFilename(fallback: 'receipt.pdf');
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(widget.receipt.bytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved as $name')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save the receipt.'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Save to device',
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.gold,
                    ),
                  )
                : const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body: SfPdfViewer.memory(
        widget.receipt.bytes,
        canShowScrollHead: true,
        canShowScrollStatus: true,
      ),
    );
  }
}
