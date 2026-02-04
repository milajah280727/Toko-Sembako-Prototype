import 'dart:math';
import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart'; // Tampilan Barcode
import 'package:tokosembakovawal/barcode_scanner_dialog.dart';
import '../../supabase_service.dart';
import '../../models/product_model.dart';
import '../../barcode_scanner_dialog.dart';


class ProductFormPage extends StatefulWidget {
  final Product? product; 

  const ProductFormPage({super.key, this.product});

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _namaController = TextEditingController();
  final _kategoriController = TextEditingController();
  final _hargaController = TextEditingController();
  final _stokController = TextEditingController();
  final _barcodeController = TextEditingController();

  bool _isLoading = false;
  final int _currentUserId = 1; 

  @override
  void initState() {
    super.initState();
    
    if (widget.product == null) {
      // MODE TAMBAH BARU
      _barcodeController.text = _generateRandomBarcode(); // Auto generate dulu
      _namaController.text = '';
      _kategoriController.text = '';
      _hargaController.text = '';
      _stokController.text = '0';
    } else {
      // MODE EDIT
      _namaController.text = widget.product!.namaProduk;
      _kategoriController.text = widget.product!.kategori;
      _hargaController.text = widget.product!.hargaJual.toString();
      _stokController.text = widget.product!.stok.toString();
      _barcodeController.text = widget.product!.barcode;
    }
  }

  String _generateRandomBarcode() {
    final random = Random();
    var barcode = '';
    for (int i = 0; i < 8; i++) {
      barcode += random.nextInt(10).toString();
    }
    return barcode;
  }

  // FUNGSI BUKA SCANNER
  void _startScan() async {
    // Buka dialog scanner widget baru
    final scannedCode = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BarcodeScannerDialog(),
      ),
    );

    // Jika scan berhasil (tidak null), masuk ke kolom
    if (scannedCode != null) {
      setState(() {
        _barcodeController.text = scannedCode;
      });
    }
  }

  Future<void> _saveProduct() async {
    if (_namaController.text.isEmpty || _hargaController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nama dan Harga wajib diisi!')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newProduct = Product(
        id: widget.product?.id, 
        namaProduk: _namaController.text,
        kategori: _kategoriController.text.isEmpty ? 'Umum' : _kategoriController.text,
        hargaJual: int.parse(_hargaController.text),
        stok: int.parse(_stokController.text.isEmpty ? '0' : _stokController.text),
        barcode: _barcodeController.text,
      );

      if (widget.product == null) {
        await SupabaseService().createProduct(newProduct.toMap());
        await SupabaseService().addLog(_currentUserId, 'Menambah produk baru: ${_namaController.text}');
      } else {
        await SupabaseService().updateProduct(newProduct.id!, newProduct.toMap());
        await SupabaseService().addLog(_currentUserId, 'Mengedit produk: ${_namaController.text}');
      }

      if (mounted) {
        Navigator.pop(context, true); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data berhasil disimpan')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Tambah Produk' : 'Edit Produk'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // --- AREA BARCODE ---
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Barcode Produk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        // TOMBOL SCAN BARCODE BARU
                        IconButton(
                          icon: const Icon(Icons.qr_code_scanner, color: Colors.deepPurple),
                          onPressed: _startScan,
                          tooltip: 'Pindai Barcode',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 80,
                      child: Center(
                        child: BarcodeWidget(
                          barcode: Barcode.code128(),
                          data: _barcodeController.text,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _barcodeController.text,
                      style: const TextStyle(letterSpacing: 4.0, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // --- FORM INPUT ---
              TextField(
                controller: _namaController,
                decoration: const InputDecoration(labelText: 'Nama Produk', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _kategoriController,
                decoration: const InputDecoration(labelText: 'Kategori', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _hargaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Harga Jual', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _stokController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stok Awal', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProduct,
                  child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : const Text('SIMPAN'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}