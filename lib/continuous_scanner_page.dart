import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/product_model.dart';

// Kelas helper untuk menyimpan sementara produk dan jumlahnya di sesi scan
class ScannedItem {
  final Product product;
  int qty;

  ScannedItem({required this.product, this.qty = 1});
}

class ContinuousScannerPage extends StatefulWidget {
  final List<Product> allProducts;

  const ContinuousScannerPage({super.key, required this.allProducts});

  @override
  State<ContinuousScannerPage> createState() => _ContinuousScannerPageState();
}

class _ContinuousScannerPageState extends State<ContinuousScannerPage> {
  // Menggunakan Map agar jika barang yang sama discan, kita update Qty, bukan bikin baru
  final Map<int, ScannedItem> _sessionMap = {};
  
  DateTime? _lastScanTime;
  final ScrollController _scrollController = ScrollController();

  void _handleDetect(BarcodeCapture capture) {
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null) return;

    // Debounce: Hanya scan tiap 800ms agar tidak double
    final now = DateTime.now();
    if (_lastScanTime != null && now.difference(_lastScanTime!) < const Duration(milliseconds: 800)) {
      return;
    }

    final product = widget.allProducts.firstWhere(
      (p) => p.barcode == code,
      orElse: () => Product(
        id: -1, namaProduk: 'Tidak Ditemukan', kategori: '', hargaJual: 0, stok: 0, barcode: '',
      ),
    );

    if (product.id != -1) {
      setState(() {
        _lastScanTime = now;

        // Logika Agregasi: Jika barang sudah ada di map, tambahkan Qty. Jika belum, buat baru.
        if (_sessionMap.containsKey(product.id!)) {
          final item = _sessionMap[product.id]!;
          // Cek stok sebelum tambah
          if (item.qty < product.stok) {
            item.qty++;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Stok ${product.namaProduk} maksimal tercapai!')),
            );
          }
        } else {
          // Tambahkan baru jika stok > 0
          if (product.stok > 0) {
            _sessionMap[product.id!] = ScannedItem(product: product, qty: 1);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Stok ${product.namaProduk} habis!')),
            );
          }
        }
      });
    } else {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barcode tidak terdaftar!'), backgroundColor: Colors.red),
      );
    }
  }

  // Fungsi manual tambah qty lewat tombol +
  void _incrementQty(int productId) {
    setState(() {
      final item = _sessionMap[productId]!;
      if (item.qty < item.product.stok) {
        item.qty++;
      }
    });
  }

  // Fungsi manual kurang qty lewat tombol -
  void _decrementQty(int productId) {
    setState(() {
      final item = _sessionMap[productId]!;
      if (item.qty > 1) {
        item.qty--;
      } else {
        // Jika qty 1 lalu dikurangi, hapus dari list
        _sessionMap.remove(productId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barang (Qty)'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle),
            onPressed: () {
              // Kirim list ScannedItem kembali ke halaman Kasir
              Navigator.pop(context, _sessionMap.values.toList());
            },
          )
        ],
      ),
      body: Column(
        children: [
          // --- AREA KAMERA ---
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                MobileScanner(onDetect: _handleDetect),
                // Overlay Kotak Panduan
                Center(
                  child: Container(
                    width: 250, height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const Positioned(
                  bottom: 30,
                  left: 0, right: 0,
                  child: Text('Scan ulang barang yang sama untuk menambah Qty', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
          
          // --- DAFTAR BARANG (AGREGASI) ---
          Expanded(
            flex: 1, // Bagian bawah
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Barang Terpilih', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Total Item: ', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _sessionMap.length,
                      itemBuilder: (context, index) {
                        // Ambil key dan value dari map
                        final entry = _sessionMap.entries.elementAt(index);
                        final item = entry.value;
                        
                        return ListTile(
                          title: Text(item.product.namaProduk, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('Stok Tersedia: ${item.product.stok}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // TOMBOL -
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                color: Colors.red,
                                onPressed: () => _decrementQty(item.product.id!),
                              ),
                              Container(
                                width: 40,
                                alignment: Alignment.center,
                                child: Text('${item.qty}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ),
                              // TOMBOL +
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                color: Colors.green,
                                onPressed: () => _incrementQty(item.product.id!),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}