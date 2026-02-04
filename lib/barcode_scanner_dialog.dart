import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// Widget scanner yang bisa dipanggil di mana saja
class BarcodeScannerDialog extends StatelessWidget {
  const BarcodeScannerDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
      body: MobileScanner(
        onDetect: (BarcodeCapture capture) {
          final code = capture.barcodes.firstOrNull?.rawValue;

          if (code != null) {
            // Tutup dialog dan kirim kode kembali
            Navigator.pop(context, code);
          }
        },
      ),
    );
  }
}