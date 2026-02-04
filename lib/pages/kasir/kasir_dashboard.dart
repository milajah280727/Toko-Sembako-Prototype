import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // Import Scanner
import '../../supabase_service.dart';
import '../../models/product_model.dart';
import '../login_page.dart';

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
  
  // Variabel Search & Scan
  final TextEditingController _searchController = TextEditingController();
  bool _isScanning = false; // Status kamera
  
  final int _currentUserId = 2; 

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

  // --- LOGIKA SCAN BARCODE ---
  void _startScan() {
    setState(() => _isScanning = true);
    
    showDialog(
      context: context,
      barrierDismissible: false, // Tidak bisa tutup klik luar
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Scan Barcode')),
        body: MobileScanner(
          onDetect: (BarcodeCapture capture) {
            final code = capture.barcodes.firstOrNull?.rawValue;
            
            // Jika barcode terdeteksi dan tidak null
            if (code != null) {
              // Cari produk berdasarkan barcode
              final product = _products.firstWhere(
                (p) => p.barcode == code,
                orElse: () => Product( // Produk dummy jika tidak ketemu
                  id: -1, 
                  namaProduk: 'Tidak Ditemukan', 
                  kategori: '', 
                  hargaJual: 0, 
                  stok: 0, 
                  barcode: ''
                ), 
              );

              if (product.id != -1) {
                _addToCart(product);
                setState(() => _isScanning = false);
                Navigator.pop(context); // Tutup scanner
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ditambahkan: ${product.namaProduk}'))
                );
              }
            }
          },
        ),
      ),
    );
  }

  int get _totalPrice {
    int total = 0;
    _cart.forEach((key, item) => total += item.product.hargaJual * item.qty);
    return total;
  }

  void _addToCart(Product product) {
    if (product.id == -1) return; // Jika produk dummy
    if (product.stok <= 0) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stok ${product.namaProduk} habis!')));
      return;
    }

    setState(() {
      if (_cart.containsKey(product.id!)) {
        if (_cart[product.id]!.qty < product.stok) {
          _cart[product.id]!.qty++;
        } else {
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stok maksimal tercapai')));
        }
      } else {
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
        title: const Text('Pembayaran'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Total: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ').format(_totalPrice)}'),
            const SizedBox(height: 10),
            TextField(controller: uangController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Uang Diterima')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              int uangDiterima = int.tryParse(uangController.text) ?? 0;
              if (uangDiterima < _totalPrice) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uang kurang!')));
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
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Transaksi Berhasil'),
                    content: Text('Kembalian: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ').format(kembalian)}'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _cart.clear();
                            _loadProducts();
                          });
                        },
                        child: const Text('OK'),
                      )
                    ],
                  ),
                );
              }
            },
            child: const Text('Bayar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage())),
          )
        ],
      ),
      body: Column(
        children: [
          // --- AREA ATAS: SEARCH & SCAN ---
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.orange[50],
            child: Column(
              children: [
                // 1. Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari nama produk...',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                  onChanged: _filterProducts, // Panggil fungsi filter saat mengetik
                ),
                const SizedBox(height: 8),
                // 2. Tombol Scan Barcode
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _startScan,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('SCAN BARCODE'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                  ),
                )
              ],
            ),
          ),

          // --- AREA TENGAH: LIST PRODUK (Filtered) ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 3 / 2,
                    ),
                    itemCount: _filteredProducts.length, // PAKAI FILTERED PRODUCTS
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      return Card(
                        child: InkWell(
                          onTap: () => _addToCart(product),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(product.namaProduk, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                Text('Stok: ${product.stok}', style: const TextStyle(fontSize: 10, color: Colors.red)),
                                Text('Rp ${product.hargaJual}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // --- AREA BAWAH: KERANJANG (Tetap Sama) ---
          Container(
            height: 250,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              border: Border(top: BorderSide(color: Colors.orange, width: 2)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Keranjang', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('Total: Rp $_totalPrice', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _cart.length,
                    itemBuilder: (context, index) {
                      final item = _cart.values.toList()[index];
                      return ListTile(
                        title: Text(item.product.namaProduk),
                        subtitle: Text('${item.qty} x Rp ${item.product.hargaJual}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.remove), onPressed: () => _removeFromCart(item.product.id!)),
                            IconButton(icon: const Icon(Icons.delete), color: Colors.red, onPressed: () => setState(() => _cart.remove(item.product.id!))),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    onPressed: _cart.isEmpty ? null : _processCheckout,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('BAYAR TRANSAKSI', style: TextStyle(color: Colors.white)),
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