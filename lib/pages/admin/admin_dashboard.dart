import 'package:flutter/material.dart';
import '../../supabase_service.dart';
import '../../models/product_model.dart';
import 'product_form_page.dart';
import '../login_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<Product> _products = [];
  bool _isLoading = true;
  final int _currentUserId = 1; // ID Admin

  @override
  void initState() {
    super.initState();
    _refreshProductList();
  }

  Future<void> _refreshProductList() async {
    setState(() => _isLoading = true);
    _products = await SupabaseService().getAllProducts();
    
    // --- LOG: Membuka List Produk ---
    await SupabaseService().addLog(_currentUserId, 'Admin membuka daftar produk');
    
    setState(() => _isLoading = false);
  }

  // UBAH PARAMETER MENJADI OBJECT PRODUK
  Future<void> _deleteProduct(Product product) async {
    final confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Produk'),
        content: Text('Apakah anda yakin ingin menghapus "${product.namaProduk}" ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );

    if (confirm == true) {
      await SupabaseService().deleteProduct(product.id!);
      
      // --- LOG: Menghapus Produk (Beserta Nama) ---
      await SupabaseService().addLog(_currentUserId, 'Menghapus produk: ${product.namaProduk}');
      
      _refreshProductList(); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produk dihapus')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Produk'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProductFormPage()),
          );
          if (result == true) {
            _refreshProductList();
          }
        },
        child: const Icon(Icons.add),
        backgroundColor: Colors.orange,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? const Center(child: Text('Belum ada data produk'))
              : ListView.builder(
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    return Card(
                      margin: const EdgeInsets.all(10),
                      child: ListTile(
                        title: Text(product.namaProduk, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Kategori: ${product.kategori} | Stok: ${product.stok}'),
                        trailing: Text('Rp ${product.hargaJual}'),
                        leading: const CircleAvatar(child: Icon(Icons.boy)),
                        onTap: () async {
                           final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => ProductFormPage(product: product)),
                          );
                          if (result == true) _refreshProductList();
                        },
                        // KIRIM OBJECT PRODUK KE FUNGSI DELETE
                        onLongPress: () => _deleteProduct(product), 
                      ),
                    );
                  },
                ),
    );
  }
}