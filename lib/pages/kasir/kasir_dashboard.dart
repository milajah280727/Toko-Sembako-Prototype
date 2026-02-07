import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../supabase_service.dart';
import '../../models/product_model.dart';
import '../login_page.dart';
import '../../continuous_scanner_page.dart';

// Class untuk Keranjang Utama (Lokal Dashboard)
class CartItem {
  final Product product;
  int qty;
  CartItem({required this.product, this.qty = 1});
}

class KasirDashboard extends StatefulWidget {
  const KasirDashboard({super.key});

  @override
  State<KasirDashboard> createState() => _KasirDashboardState();
}

class _KasirDashboardState extends State<KasirDashboard> {
  List<Product> _products = []; // Produk Asli
  List<Product> _filteredProducts = []; // Produk setelah di filter search
  Map<int, CartItem> _cart = {};
  bool _isLoading = true;

  // Variabel Search
  final TextEditingController _searchController = TextEditingController();
  final _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  
  final int _currentUserId = 2; // Hardcoded ID Kasir

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    _products = await SupabaseService().getAllProducts();
    _filteredProducts = _products; // Set awal sama semua
    setState(() => _isLoading = false);
  }

  // --- LOGIKA SEARCH BAR ---
  void _filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = _products;
      } else {
        _filteredProducts = _products
            .where((p) => p.namaProduk.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  // --- LOGIKA SCAN BARCODE (Membuka Halaman Continuous Scan) ---
  void _startScan() async {
    // Navigasi ke halaman scanner baru
    final List<ScannedItem>? scannedItems = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContinuousScannerPage(allProducts: _products),
      ),
    );

    // Jika user menekan tombol Selesai di halaman scanner
    if (scannedItems != null && scannedItems.isNotEmpty) {
      // Loop setiap item yang discan di halaman scanner
      for (var item in scannedItems) {
        // Loop lagi sebanyak Qty untuk masuk ke keranjang utama
        for (int i = 0; i < item.qty; i++) {
          _addToCart(item.product);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${scannedItems.length} jenis barang ditambahkan'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  int get _totalPrice {
    int total = 0;
    _cart.forEach((key, item) => total += item.product.hargaJual * item.qty);
    return total;
  }

  // Fungsi Tambah ke Keranjang Utama
  void _addToCart(Product product) {
    if (product.id == -1) return; // Cegah produk dummy
    if (product.stok <= 0) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stok ${product.namaProduk} habis!')));
      return;
    }

    setState(() {
      if (_cart.containsKey(product.id!)) {
        // Jika barang sudah ada, cek stok max
        if (_cart[product.id]!.qty < product.stok) {
          _cart[product.id]!.qty++;
        } else {
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stok maksimal tercapai')));
        }
      } else {
        // Jika barang belum ada, buat baru
        _cart[product.id!] = CartItem(product: product);
      }
    });
  }

  void _removeFromCart(int productId) {
    setState(() {
      if (_cart.containsKey(productId)) {
        if (_cart[productId]!.qty > 1) {
          _cart[productId]!.qty--;
        } else {
          _cart.remove(productId);
        }
      }
    });
  }

  void _processCheckout() async {
    if (_cart.isEmpty) return;
    List<Map<String, dynamic>> items = [];
    _cart.forEach((key, item) {
      items.add({
        'id_produk': item.product.id,
        'qty': item.qty,
        'subtotal': item.product.hargaJual * item.qty,
      });
    });

    TextEditingController uangController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Pembayaran', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Modern Tampilan Total
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text('Total Tagihan', style: TextStyle(fontSize: 12, color: Colors.orange)),
                  const SizedBox(height: 4),
                  Text(
                    _currencyFormat.format(_totalPrice),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: uangController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'Uang Diterima',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    int uangDiterima = int.tryParse(uangController.text) ?? 0;
                    if (uangDiterima < _totalPrice) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Uang kurang!'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    int kembalian = uangDiterima - _totalPrice;
                    await SupabaseService().saveTransaction(
                      idUser: _currentUserId,
                      totalBayar: _totalPrice,
                      uangDiterima: uangDiterima,
                      kembalian: kembalian,
                      items: items,
                    );

                    if (mounted) {
                      Navigator.pop(context);
                      // Dialog Sukses Modern
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.green,
                                child: Icon(Icons.check, color: Colors.white, size: 40),
                              ),
                              const SizedBox(height: 16),
                              const Text('Transaksi Berhasil', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              const SizedBox(height: 8),
                              Text('Kembalian: ${_currencyFormat.format(kembalian)}'),
                            ],
                          ),
                          actions: [
                            SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  setState(() {
                                    _cart.clear();
                                    _loadProducts();
                                  });
                                },
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Bayar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Background abu-abu sangat muda
      appBar: AppBar(
        title: const Text('Kasir Sembako'),
        backgroundColor: Colors.orange,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage())),
          )
        ],
      ),
      body: Column(
        children: [
          // --- AREA ATAS: SEARCH & SCAN (Modern) ---
          Container(
            color: Colors.orange,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                // 1. Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 3))
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari nama produk...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none, // Hilangkan border default
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                    onChanged: _filterProducts,
                  ),
                ),
                const SizedBox(height: 12),
                // 2. Tombol Scan Barcode
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton.icon(
                    onPressed: _startScan,
                    icon: const Icon(Icons.qr_code_scanner, size: 20),
                    label: const Text('SCAN BARCODE', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.black26,
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                )
              ],
            ),
          ),

          // --- AREA TENGAH: LIST PRODUK (UI MODERN) ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.75, // Proporsi vertikal
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      
                      // Logika Ikon Fallback (Jika tidak ada gambar)
                      IconData categoryIcon = Icons.shopping_bag_outlined;
                      Color iconColor = Colors.orange;
                      if (product.kategori.toLowerCase().contains('beras')) {
                        categoryIcon = Icons.grain; 
                        iconColor = Colors.amber;
                      } else if (product.kategori.toLowerCase().contains('minyak')) {
                        categoryIcon = Icons.opacity; 
                        iconColor = Colors.deepPurple;
                      } else if (product.kategori.toLowerCase().contains('gula')) {
                        categoryIcon = Icons.water_drop; 
                        iconColor = Colors.brown;
                      }

                      return Card(
                        elevation: 2,
                        shadowColor: Colors.black.withOpacity(0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: InkWell(
                          onTap: () => _addToCart(product),
                          borderRadius: BorderRadius.circular(16),
                          splashColor: Colors.orange.withOpacity(0.2),
                          child: Column(
                            children: [
                              // Area Gambar / Ikon
                              Expanded(
                                flex: 4,
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: iconColor.withOpacity(0.1), // Warna background fallback
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(16),
                                    ),
                                  ),
                                  // ClipRRect memastikan gambar tidak keluar sudut melengkung
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(16),
                                    ),
                                    child: (product.gambar != null && product.gambar!.isNotEmpty)
                                        ? Image.network(
                                            product.gambar!,
                                            width: double.infinity,
                                            height: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              // Jika gagal load gambar, tampilkan ikon
                                              return Icon(categoryIcon, size: 50, color: iconColor);
                                            },
                                          )
                                        : Center(
                                            child: Icon(
                                              categoryIcon,
                                              size: 50,
                                              color: iconColor,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              // Area Info
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.namaProduk,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Colors.black87,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            product.kategori,
                                            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                          ),
                                        ],
                                      ),
                                      
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _currencyFormat.format(product.hargaJual),
                                            style: const TextStyle(
                                              color: Colors.orange,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: product.stok < 5 ? Colors.red.shade50 : Colors.grey.shade200,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Sisa: ${product.stok}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: product.stok < 5 ? Colors.red : Colors.black54,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // --- AREA BAWAH: KERANJANG (Modern Bottom Sheet) ---
          Container(
            height: 260,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, -5))
              ],
            ),
            child: Column(
              children: [
                // Handle Bar (Estetika)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                // Header Keranjang
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Keranjang', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                      Text('Total: ${_currencyFormat.format(_totalPrice)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange)),
                    ],
                  ),
                ),
                
                Divider(height: 1, color: Colors.grey[200]),

                // List Item Keranjang
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _cart.length,
                    itemBuilder: (context, index) {
                      final item = _cart.values.toList()[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              // Info Barang
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.product.namaProduk, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text('${_currencyFormat.format(item.product.hargaJual)} x ${item.qty}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              // Tombol Aksi
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Tombol Kurang
                                  InkWell(
                                    onTap: () => _removeFromCart(item.product.id!),
                                    child: const CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Colors.white,
                                      child: Icon(Icons.remove, size: 16, color: Colors.black54),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Tombol Hapus Total
                                  InkWell(
                                    onTap: () => setState(() => _cart.remove(item.product.id!)),
                                    child: const CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Colors.red,
                                      child: Icon(Icons.delete_outline, size: 16, color: Colors.white),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Tombol Bayar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: ElevatedButton(
                    onPressed: _cart.isEmpty ? null : _processCheckout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('BAYAR TRANSAKSI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}