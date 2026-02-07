import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// Ubah dari StatelessWidget menjadi StatefulWidget
class BarcodeScannerDialog extends StatefulWidget {
  const BarcodeScannerDialog({super.key});

  @override
  State<BarcodeScannerDialog> createState() => _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends State<BarcodeScannerDialog> {
  // Tambahkan variabel penanda untuk mencegah scan ganda
  bool _isScanned = false;

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
          // Cek jika belum discan sebelumnya
          if (!_isScanned) {
            final code = capture.barcodes.firstOrNull?.rawValue;

            if (code != null) {
              // Set flag menjadi true agar tidak pop lagi
              setState(() {
                _isScanned = true;
              });
              
              // Tutup dialog dan kirim kode kembali
              Navigator.pop(context, code);
            }
          }
        },
      ),
    );
  }
}