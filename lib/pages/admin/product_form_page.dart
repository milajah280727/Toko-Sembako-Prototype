import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

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
  
  // Variabel untuk Gambar
  File? _imageFile;
  String? _existingImageUrl; // Untuk mode edit, simpan URL gambar lama
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    
    if (widget.product == null) {
      _barcodeController.text = _generateRandomBarcode();
      _namaController.text = '';
      _kategoriController.text = '';
      _hargaController.text = '';
      _stokController.text = '0';
    } else {
      // MODE EDIT
      final p = widget.product!;
      _namaController.text = p.namaProduk;
      _kategoriController.text = p.kategori;
      _hargaController.text = p.hargaJual.toString();
      _stokController.text = p.stok.toString();
      _barcodeController.text = p.barcode;
      _existingImageUrl = p.gambar; // Simpan gambar lama
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

  // --- FUNGSI PILIH GAMBAR ---
  // --- FUNGSI PILIH GAMBAR (DENGAN KOMPRESI) ---
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      // Tampilkan loading sementara karena kompresi butuh waktu
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        // Panggil fungsi kompresi
        File compressedImage = await _compressImage(File(image.path));

        if (mounted) {
          // Tutup dialog loading
          Navigator.pop(context);
          
          // Update state dengan gambar yang sudah dikecilkan
          setState(() {
            _imageFile = compressedImage;
          });
        }
      } catch (e) {
        if (mounted) Navigator.pop(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memproses gambar: $e')),
          );
        }
      }
    }
  }

  // --- FUNGSI KOMPRESI GAMBAR ---
  Future<File> _compressImage(File file) async {
    // Tentukan jalur penyimpanan sementara untuk gambar hasil kompresi
    final path = file.absolute.path;
    final lastIndex = path.lastIndexOf(RegExp(r'\.'));
    final split = path.substring(0, (lastIndex + 1));
    final outPath = '${split}compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

    // Lakukan kompresi
    // quality: 70 (0-100), semakin kecil semakin jelek kualitasnya tapi ukurannya kecil
    // minWidth: 800, memperkecil resolusi lebar jadi 800px (cukup besar untuk produk)
    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      outPath,
      quality: 70,
      minWidth: 800,
      minHeight: 600,
    );

    if (result == null) {
      return file; // Jika gagal kompresi, pakai yang asli
    }
    return File(result.path);
  }

  // --- FUNGSI UPLOAD GAMBAR KE SUPABASE STORAGE (VERSI PERBAIKAN) ---
  Future<String> _uploadImage(String fileName) async {
    // Jika tidak ada gambar baru dan mode edit, pakai gambar lama
    if (_imageFile == null) return _existingImageUrl ?? ''; // Jika baru dan kosong, return string kosong

    try {
      // Pastikan nama bucket di sini SAMA PERSIS dengan nama di Supabase Dashboard
      String bucketName = 'products-image'; 
      
      final path = '$fileName-${DateTime.now().millisecondsSinceEpoch}';
      
      print("Mulai upload ke bucket: $bucketName dengan path: $path"); // Debugging

      // Upload
      await Supabase.instance.client.storage.from(bucketName).upload(path, _imageFile!);

      // Ambil URL Publik
      final imageUrl = Supabase.instance.client.storage.from(bucketName).getPublicUrl(path);
      
      print("Sukses Upload: $imageUrl"); // Debugging
      return imageUrl;
    } catch (e) {
      print("GAGAL Upload Image: $e"); // Debugging
      // Lempar error agar bisa ditangkap di _saveProduct
      throw Exception("Gagal upload gambar: $e");
    }
  }

  void _startScan() async {
    final scannedCode = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BarcodeScannerDialog()),
    );

    if (scannedCode != null) {
      setState(() => _barcodeController.text = scannedCode);
    }
  }

  // --- FUNGSI CETAK BARCODE KE PDF ---
  Future<void> _generateAndPrintBarcode() async {
    final pdf = pw.Document();
    
    // Ambil gambar barcode (konversi widget ke PDF agak rumit, 
    // jadi kita buat ulang barcode menggunakan library PDF)
    
    // Gunakan nama file untuk PDF jika belum disimpan, atau nama produk
    String productName = _namaController.text.isEmpty ? 'Produk Baru' : _namaController.text;
    String price = _hargaController.text.isEmpty ? '0' : _hargaController.text;
    String barcodeData = _barcodeController.text;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6, // Ukuran kecil cocok untuk label
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(productName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),
                pw.Text('Rp $price', style: pw.TextStyle(fontSize: 14, color: PdfColors.orange800)),
                pw.SizedBox(height: 10),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(),
                  data: barcodeData,
                  width: 200,
                  height: 80,
                  drawText: false,
                ),
                pw.SizedBox(height: 5),
                pw.Text(barcodeData, style: const pw.TextStyle(fontSize: 12)),
              ],
            ),
          );
        },
      ),
    );

    // Tampilkan dialog preview/print
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Barcode_$productName.pdf',
    );
  }

    // --- FUNGSI SIMPAN PRODUK (VERSI PERBAIKAN) ---
  Future<void> _saveProduct() async {
    if (_namaController.text.isEmpty || _hargaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama dan Harga wajib diisi!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Coba Upload Gambar Dulu
      // Jika gagal upload, akan langsung masuk ke 'catch' di bawah
      String? finalImageUrl = await _uploadImage(_namaController.text);

      // Jika produk baru dan tidak ada gambar, kita set null atau kosong
      if (finalImageUrl == null && _existingImageUrl != null && widget.product != null) {
        finalImageUrl = _existingImageUrl;
      }

      final newProduct = Product(
        id: widget.product?.id, 
        namaProduk: _namaController.text,
        kategori: _kategoriController.text.isEmpty ? 'Umum' : _kategoriController.text,
        hargaJual: int.parse(_hargaController.text),
        stok: int.parse(_stokController.text.isEmpty ? '0' : _stokController.text),
        barcode: _barcodeController.text,
        gambar: finalImageUrl, // Kirim URL gambar
      );

      // 2. Simpan Data ke Database
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
      // Bagian ini akan muncul jika upload gagal atau simpan database gagal
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal Menyimpan: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.product == null ? 'Tambah Produk' : 'Edit Produk'),
        backgroundColor: Colors.orange,
        elevation: 0,
        actions: [
          // Tombol Cetak Barcode
          IconButton(
            onPressed: _isLoading ? null : _generateAndPrintBarcode,
            icon: const Icon(Icons.print),
            tooltip: 'Cetak Barcode / Save PDF',
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- AREA GAMBAR (BARU) ---
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _imageFile != null
                    ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.file(_imageFile!, width: double.infinity, height: double.infinity, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 10, right: 10,
                            child: CircleAvatar(
                              backgroundColor: Colors.red,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white),
                                onPressed: () => setState(() => _imageFile = null),
                              ),
                            ),
                          )
                        ],
                      )
                    : (_existingImageUrl != null && widget.product != null)
                        ? Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.network(_existingImageUrl!, width: double.infinity, height: double.infinity, fit: BoxFit.cover),
                              ),
                              Positioned(
                                bottom: 10, left: 0, right: 0,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text('Tap untuk ganti gambar', style: TextStyle(color: Colors.white)),
                                  ),
                                ),
                              )
                            ],
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined, size: 50, color: Colors.grey),
                              Text('Tambah Foto Produk', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
              ),
            ),
            const SizedBox(height: 24),

            // --- KARTU BARCODE ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.qr_code_2, color: Colors.deepPurple),
                          const SizedBox(width: 8),
                          const Text('Barcode Produk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(color: Colors.deepPurple.shade50, borderRadius: BorderRadius.circular(8)),
                        child: IconButton(
                          icon: const Icon(Icons.qr_code_scanner, color: Colors.deepPurple),
                          onPressed: _startScan,
                          tooltip: 'Pindai Barcode',
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                    child: BarcodeWidget(
                      barcode: Barcode.code128(),
                      data: _barcodeController.text,
                      color: Colors.black,
                      height: 50,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(_barcodeController.text, style: const TextStyle(letterSpacing: 2.0, fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- FORM INPUT ---
            _buildInputField(_namaController, 'Nama Produk', Icons.inventory_2_outlined, false),
            const SizedBox(height: 16),
            _buildInputField(_kategoriController, 'Kategori', Icons.category_outlined, false),
            const SizedBox(height: 16),
            _buildInputField(_hargaController, 'Harga Jual', Icons.sell_outlined, true),
            const SizedBox(height: 16),
            _buildInputField(_stokController, 'Stok Awal', Icons.layers_outlined, true),
            
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                child: _isLoading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) 
                    : const Text('SIMPAN PRODUK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String label, IconData icon, bool isNumber) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            prefixIcon: Icon(icon, color: Colors.orange),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.orange, width: 2)),
          ),
        ),
      ],
    );
  }
}