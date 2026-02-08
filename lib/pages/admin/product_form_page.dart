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
import 'package:intl/intl.dart';

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
  final _barcodeController = TextEditingController();
  final _hargaBeliController = TextEditingController();

  bool _isLoading = false;
  final int _currentUserId = 1;

  // Variabel untuk Gambar
  File? _imageFile;
  String? _existingImageUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    if (widget.product == null) {
      // MODE TAMBAH BARU
      _barcodeController.text = _generateRandomBarcode();
      _namaController.text = '';
      _kategoriController.text = '';
      _hargaController.text = '';
      _hargaBeliController.text = '0';
    } else {
      // MODE EDIT (Hanya data master, Stok diambil dari display saja bukan diinput disini)
      final p = widget.product!;
      _namaController.text = p.namaProduk;
      _kategoriController.text = p.kategori;
      _hargaController.text = p.hargaJual.toString();
      _barcodeController.text = p.barcode;
      _existingImageUrl = p.gambar;
      _hargaBeliController.text = p.hargaBeli.toString();
      
      // Catatan: Kita TIDAK mengembalikan nilai stok atau exp ke input form,
      // karena sekarang stok diatur lewat Restock.
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

  // --- FUNGSI PILIH SUMBER GAMBAR (KAMERA / GALERI) ---
  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Container(
            child: Wrap(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Galeri'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: const Text('Kamera'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- FUNGSI AMBIL & KOMPRESI GAMBAR ---
  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);

    if (image != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        File compressedImage = await _compressImage(File(image.path));

        if (mounted) {
          Navigator.pop(context);
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

  Future<File> _compressImage(File file) async {
    final path = file.absolute.path;
    final lastIndex = path.lastIndexOf(RegExp(r'\.'));
    final split = path.substring(0, (lastIndex + 1));
    final outPath =
        '${split}compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      outPath,
      quality: 70,
      minWidth: 800,
      minHeight: 600,
    );

    if (result == null) {
      return file;
    }
    return File(result.path);
  }

  Future<String> _uploadImage(String fileName) async {
    if (_imageFile == null) return _existingImageUrl ?? '';

    try {
      String bucketName = 'products-image';
      final path = '$fileName-${DateTime.now().millisecondsSinceEpoch}';

      print("Mulai upload ke bucket: $bucketName dengan path: $path");
      await Supabase.instance.client.storage
          .from(bucketName)
          .upload(path, _imageFile!);
      final imageUrl = Supabase.instance.client.storage
          .from(bucketName)
          .getPublicUrl(path);
      print("Sukses Upload: $imageUrl");
      return imageUrl;
    } catch (e) {
      print("GAGAL Upload Image: $e");
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

  Future<void> _generateAndPrintBarcode() async {
    final pdf = pw.Document();
    String productName = _namaController.text.isEmpty
        ? 'Produk Baru'
        : _namaController.text;
    String price = _hargaController.text.isEmpty ? '0' : _hargaController.text;
    String barcodeData = _barcodeController.text;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6,
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  productName,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Rp $price',
                  style: pw.TextStyle(fontSize: 14, color: PdfColors.orange800),
                ),
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

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Barcode_$productName.pdf',
    );
  }

  Future<void> _saveProduct() async {
    if (_namaController.text.isEmpty || _hargaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama dan Harga wajib diisi!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? finalImageUrl = await _uploadImage(_namaController.text);

      if (finalImageUrl == null &&
          _existingImageUrl != null &&
          widget.product != null) {
        finalImageUrl = _existingImageUrl;
      }

      int parsedHargaBeli = 0;
      if (_hargaBeliController.text.isNotEmpty) {
        parsedHargaBeli = int.parse(_hargaBeliController.text);
      }

      // Membuat objek Product (Hanya data Master)
      final newProduct = Product(
        id: widget.product?.id,
        namaProduk: _namaController.text,
        kategori: _kategoriController.text.isEmpty
            ? 'Umum'
            : _kategoriController.text,
        hargaJual: int.parse(_hargaController.text),
        barcode: _barcodeController.text,
        gambar: finalImageUrl,
        hargaBeli: parsedHargaBeli,
        // Stok dan Exp di-set default untuk Master Product
        totalStok: 0, 
        nearestExpDate: null,
      );

      if (widget.product == null) {
        await SupabaseService().createProduct(newProduct.toMap());
        await SupabaseService().addLog(
          _currentUserId,
          'Menambah produk baru: ${_namaController.text}',
        );
      } else {
        await SupabaseService().updateProduct(
          newProduct.id!,
          newProduct.toMap(),
        );
        await SupabaseService().addLog(
          _currentUserId,
          'Mengedit produk: ${_namaController.text}',
        );
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
          SnackBar(
            content: Text('Gagal Menyimpan: $e'),
            backgroundColor: Colors.red,
          ),
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- AREA GAMBAR ---
            GestureDetector(
              onTap: () => _showPicker(context),
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
                            child: Image.file(
                              _imageFile!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: CircleAvatar(
                              backgroundColor: Colors.red,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white),
                                onPressed: () => setState(() => _imageFile = null),
                              ),
                            ),
                          ),
                        ],
                      )
                    : (_existingImageUrl != null && widget.product != null)
                        ? Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.network(
                                  _existingImageUrl!,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                bottom: 10,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'Tap untuk ganti gambar',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  size: 50, color: Colors.grey),
                              Text('Tap untuk ambil foto / galeri',
                                  style: TextStyle(color: Colors.grey)),
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Barcode Produk',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.qr_code_scanner,
                                  color: Colors.deepPurple),
                              onPressed: _startScan,
                              tooltip: 'Pindai Barcode',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.print, color: Colors.orange),
                              onPressed: _isLoading
                                  ? null
                                  : _generateAndPrintBarcode,
                              tooltip: 'Cetak Barcode / Save PDF',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: BarcodeWidget(
                      barcode: Barcode.code128(),
                      data: _barcodeController.text,
                      color: Colors.black,
                      height: 50,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _barcodeController.text,
                    style: const TextStyle(
                      letterSpacing: 2.0,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- FORM INPUT (HANYA DATA MASTER) ---
            _buildInputField(
              _namaController,
              'Nama Produk',
              Icons.inventory_2_outlined,
              false,
            ),
            const SizedBox(height: 16),
            _buildInputField(
              _kategoriController,
              'Kategori',
              Icons.category_outlined,
              false,
            ),
            const SizedBox(height: 16),
            _buildInputField(
              _hargaController,
              'Harga Jual',
              Icons.sell_outlined,
              true,
            ),
            const SizedBox(height: 16),
            _buildInputField(
              _hargaBeliController,
              'Harga Beli (Modal/HPP)',
              Icons.monetization_on_outlined,
              true,
            ),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Text(
                        'SIMPAN PRODUK',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(
    TextEditingController controller,
    String label,
    IconData icon,
    bool isNumber,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            prefixIcon: Icon(icon, color: Colors.orange),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.orange, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}