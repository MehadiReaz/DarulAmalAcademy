import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/state_views.dart';

/// Renders a receipt PDF fetched from `GET /student/fees/receipt/{id}`.
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
  bool _ready = false;
  late final PdfViewerController _pdfViewerController;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _ready = true);
      }
    });
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final name = widget.receipt.safeFilename(fallback: 'receipt.pdf');

      String? savedPath;
      bool usedFilePicker = false;
      try {
        savedPath = await FilePicker.saveFile(
          dialogTitle: 'Save Receipt PDF',
          fileName: name,
          bytes: widget.receipt.bytes,
        );
        usedFilePicker = true;
      } catch (e) {
        // Fall back if saveFile is not supported on device
      }

      if (usedFilePicker) {
        if (savedPath != null && savedPath.isNotEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Receipt saved successfully!')),
          );
        }
        return;
      }

      Directory? targetDir;
      if (Platform.isAndroid) {
        final extDirs = await getExternalStorageDirectories(
            type: StorageDirectory.downloads);
        if (extDirs != null && extDirs.isNotEmpty) {
          targetDir = extDirs.first;
        } else {
          targetDir = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        targetDir = await getApplicationDocumentsDirectory();
      } else {
        targetDir = await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory();
      }

      targetDir ??= await getApplicationDocumentsDirectory();
      await targetDir.create(recursive: true);

      final file = File('${targetDir.path}/$name');
      await file.writeAsBytes(widget.receipt.bytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved as $name')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save receipt: $e'),
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
      body: !_ready
          ? const LoadingView(message: 'Opening PDF receipt…')
          : LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
                  return const LoadingView(message: 'Preparing PDF viewer…');
                }
                return SfPdfViewer.memory(
                  widget.receipt.bytes,
                  key: ValueKey(widget.receipt.bytes.length),
                  controller: _pdfViewerController,
                  canShowScrollHead: true,
                  canShowScrollStatus: true,
                  onDocumentLoadFailed:
                      (PdfDocumentLoadFailedDetails details) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Failed to load PDF: ${details.description}'),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
