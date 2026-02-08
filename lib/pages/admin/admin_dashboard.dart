import 'package:flutter/material.dart';
import '../../supabase_service.dart';
import '../../models/product_model.dart';
import 'product_form_page.dart';
// TAMBAHKAN IMPORT INI
import 'restock_form_page.dart'; 
import '../login_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<Product> _products = []; // Semua produk asli
  List<Product> _filteredProducts = []; // Produk hasil filter search
  bool _isLoading = true;
  
  // Controller untuk Search
  final TextEditingController _searchController = TextEditingController();
  
  final int _currentUserId = 1; 

  @override
  void initState() {
    super.initState();
    _refreshProductList();
  }

  // --- PERUBAHAN PENTING DI SINI ---
  Future<void> _refreshProductList() async {
    setState(() => _isLoading = true);
    
    // PANGGIL FUNGSI YANG SUDAH MENGHITUNG STOK BATCH
    // Jangan pakai getAllProducts() lagi di sini
    _products = await SupabaseService().getProductsWithStock();
    
    // Sinkronkan list filtered dengan list asli saat pertama load
    _filteredProducts = List.from(_products);
    
    // --- LOG: Membuka List Produk ---
    await SupabaseService().addLog(_currentUserId, 'Admin membuka daftar produk');
    
    setState(() => _isLoading = false);
  }

  // --- FUNGSI FILTER SEARCH ---
  void _filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = List.from(_products);
      } else {
        _filteredProducts = _products
            .where((p) => p.namaProduk.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> _deleteProduct(Product product) async {
    // Dialog Konfirmasi Modern
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Produk', style: TextStyle(color: Colors.red)),
        content: Text('Yakin ingin menghapus "${product.namaProduk}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SupabaseService().deleteProduct(product.id!);
      await SupabaseService().addLog(_currentUserId, 'Menghapus produk: ${product.namaProduk}');
      
      _refreshProductList(); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produk berhasil dihapus'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Manajemen Produk'),
        backgroundColor: Colors.orange,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage())),
          )
        ],
      ),
      // --- FLOATING ACTION BUTTONS (DIPERBARUI) ---
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 1. Tombol Restock
          FloatingActionButton(
            heroTag: "btn_restock",
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RestockFormPage()),
              );
              if (result == true) _refreshProductList();
            },
            backgroundColor: Colors.orange, // Diubah jadi Orange agar konsisten
            child: const Icon(Icons.add_shopping_cart, color: Colors.white),
            tooltip: 'Stok Masuk',
          ),
          const SizedBox(height: 12),
          // 2. Tombol Tambah Produk
          FloatingActionButton.extended(
            heroTag: "btn_add_product",
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProductFormPage()),
              );
              if (result == true) _refreshProductList();
            },
            label: const Text('Tambah Produk'),
            icon: const Icon(Icons.add),
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- HEADER STATISTIK ---
          if (!_isLoading && _products.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 10, offset: Offset(0, 5))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Produk', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('${_products.length} Item', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Icon(Icons.inventory_2, color: Colors.white, size: 40),
                ],
              ),
            ),

          // --- SEARCH BAR ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5, offset: Offset(0, 3))
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari nama produk...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
                onChanged: _filterProducts,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // --- LIST PRODUK ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                : _filteredProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
                            const SizedBox(height: 10),
                            Text(
                              _products.isEmpty ? 'Belum ada data produk' : 'Produk tidak ditemukan',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), // Padding bawah ditambah agar tidak tertutup FAB
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = _filteredProducts[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: Offset(0, 2))],
                            ),
                            child: InkWell(
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => ProductFormPage(product: product)),
                                );
                                if (result == true) _refreshProductList();
                              },
                              onLongPress: () => _deleteProduct(product),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    // TAMPILKAN GAMBAR
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: (product.gambar != null && product.gambar!.isNotEmpty)
                                            ? Image.network(
                                                product.gambar!,
                                                width: double.infinity,
                                                height: double.infinity,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) => 
                                                  Icon(Icons.image_not_supported, color: Colors.grey[400]),
                                              )
                                            : Icon(Icons.shopping_bag, color: Colors.orange.shade300),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    
                                    // Info Produk
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.namaProduk,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              _buildBadge(product.kategori),
                                              const SizedBox(width: 8),
                                              // Memanggil totalStok yang sudah dihitung
                                              _buildStockBadge(product.totalStok),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text('Rp ${product.hargaJual}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                    // Aksi
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () => _deleteProduct(product),
                                      tooltip: 'Hapus',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Text(text, style: const TextStyle(fontSize: 10, color: Colors.blue)),
    );
  }

  Widget _buildStockBadge(int stok) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: stok < 5 ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: stok < 5 ? Colors.red.shade100 : Colors.green.shade100),
      ),
      child: Text('Stok: $stok', style: TextStyle(fontSize: 10, color: stok < 5 ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
    );
  }
}