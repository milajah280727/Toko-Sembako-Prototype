import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../supabase_service.dart';
import '../../models/product_model.dart';

// Model sementara untuk item di keranjang pembelian
class PurchaseItem {
  final Product product;
  int qty;
  int hargaBeli; // Harga beli satuan saat ini
  DateTime? tanggalExp; // Tanggal Kadaluarsa (WAJIB untuk Batch System)

  PurchaseItem({
    required this.product,
    this.qty = 1,
    required this.hargaBeli,
    this.tanggalExp, 
  });

  int get subtotal => qty * hargaBeli;
}

class RestockFormPage extends StatefulWidget {
  const RestockFormPage({super.key});

  @override
  State<RestockFormPage> createState() => _RestockFormPageState();
}

class _RestockFormPageState extends State<RestockFormPage> {
  // Form Controllers
  final _supplierController = TextEditingController();
  final _catatanController = TextEditingController();
  
  // Data
  List<Product> _allProducts = [];
  List<PurchaseItem> _cartItems = [];
  bool _isLoading = false;
  bool _isFetchingProducts = true;

  // Format Rupiah
  final _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final _currentUserId = 1; 

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final products = await SupabaseService().getAllProducts();
    setState(() {
      _allProducts = products;
      _isFetchingProducts = false;
    });
  }

  int get _totalBelanja {
    int total = 0;
    for (var item in _cartItems) {
      total += item.subtotal;
    }
    return total;
  }

  // --- FUNGSI TAMBAH PRODUK KE KERANJANG ---
  void _showAddProductDialog() {
    showDialog(
      context: context,
      builder: (context) => _ProductSearchDialog(
        allProducts: _allProducts,
        onSelected: (product) {
          final existingIndex = _cartItems.indexWhere((item) => item.product.id == product.id);
          
          if (existingIndex != -1) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${product.namaProduk} sudah ada di daftar')),
            );
            return;
          }

          setState(() {
            _cartItems.add(PurchaseItem(
              product: product,
              qty: 1,
              hargaBeli: product.hargaBeli,
              tanggalExp: null, // Belum dipilih
            ));
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  // --- FUNGSI PILIH TANGGAL EXPIRED PER ITEM ---
  Future<void> _selectDateForItem(PurchaseItem item) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)), // Default 1 bulan ke depan
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    
    if (picked != null) {
      setState(() {
        item.tanggalExp = picked;
      });
    }
  }

  // --- FUNGSI SIMPAN PEMBELIAN (MENGGUNAKAN BATCH SYSTEM) ---
  Future<void> _savePurchase() async {
    if (_supplierController.text.isEmpty || _cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supplier dan Daftar Barang wajib diisi!')),
      );
      return;
    }

    // Validasi: Pastikan semua barang punya tanggal kadaluarsa
    for (var item in _cartItems) {
      if (item.tanggalExp == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Harap pilih tanggal kadaluarsa untuk ${item.product.namaProduk}!')),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      // Loop setiap item dan simpan sebagai Batch baru
      for (var item in _cartItems) {
        await SupabaseService().addStockBatch(
          idProduk: item.product.id!,
          qty: item.qty,
          tanggalExp: item.tanggalExp!,
          hargaBeliSatuan: item.hargaBeli,
        );
      }

      // Catat Log Aktivitas
      await SupabaseService().addLog(
        _currentUserId,
        'Melakukan Restock dari supplier: ${_supplierController.text} senilai Rp $_totalBelanja',
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stok berhasil ditambahkan!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: Colors.red),
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
        title: const Text('Penerimaan Barang (Restock)'),
        backgroundColor: Colors.orange, // Sesuai Style Admin/Product
        elevation: 0,
      ),
      body: Column(
        children: [
          // --- FORM HEADER (Styled like Product Form) ---
          Container(
            color: Colors.orange,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                _buildInputField(_supplierController, 'Nama Supplier', Icons.local_shipping, false),
                const SizedBox(height: 10),
                _buildInputField(_catatanController, 'Catatan (Opsional)', Icons.note, false),
              ],
            ),
          ),

          // --- DAFTAR BARANG ---
          Expanded(
            child: _isFetchingProducts
                ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                : _cartItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey[300]),
                            const SizedBox(height: 10),
                            Text('Belum ada barang dipilih', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _cartItems.length,
                        itemBuilder: (context, index) {
                          final item = _cartItems[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.product.namaProduk, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 12),
                                  
                                  // ROW INPUT: Qty & Harga Beli
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildSmallInput(
                                          initialValue: item.qty.toString(),
                                          label: 'Qty',
                                          onChanged: (val) => setState(() => item.qty = int.tryParse(val) ?? 1),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _buildSmallInput(
                                          initialValue: item.hargaBeli.toString(),
                                          label: 'Harga Beli',
                                          onChanged: (val) => setState(() => item.hargaBeli = int.tryParse(val) ?? 0),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 10),
                                  const Divider(height: 1),

                                  // ROW AKSI: Pilih Tanggal Exp & Hapus
                                  Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => _selectDateForItem(item),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                            decoration: BoxDecoration(
                                              color: item.tanggalExp != null ? Colors.orange.shade50 : Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: item.tanggalExp != null ? Colors.orange.shade200 : Colors.grey.shade300),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.calendar_today, size: 16, color: item.tanggalExp != null ? Colors.orange : Colors.grey),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    item.tanggalExp == null 
                                                        ? 'Pilih Tgl Exp' 
                                                        : DateFormat('yyyy-MM-dd').format(item.tanggalExp!),
                                                    style: TextStyle(fontSize: 12, color: item.tanggalExp != null ? Colors.orange.shade900 : Colors.grey),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        onPressed: () => setState(() => _cartItems.removeAt(index)),
                                        tooltip: 'Hapus',
                                      )
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 5),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text('Subtotal: ${_currencyFormat.format(item.subtotal)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // --- FOOTER SUMMARY ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: Offset(0, -2))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Pembelian', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(_currencyFormat.format(_totalBelanja), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _savePurchase,
                  icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                  label: const Text('SIMPAN STOK'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProductDialog,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add_shopping_cart),
      ),
    );
  }
  

  // Helper Widget Input Kecil (Untuk Qty/Harga di dalam list)
  Widget _buildSmallInput({required String initialValue, required String label, required Function(String) onChanged}) {
    return TextFormField(
      initialValue: initialValue,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        isDense: true,
      ),
      onChanged: onChanged,
    );
  }

  // Helper Widget Input Besar (Untuk Header)
  Widget _buildInputField(TextEditingController controller, String label, IconData icon, bool isNumber) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: label,
        prefixIcon: Icon(icon, color: Colors.orange),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.orange, width: 2)),
      ),
    );
  }
}

// --- WIDGET DIALOG PENCARIAN PRODUK ---
class _ProductSearchDialog extends StatefulWidget {
  final List<Product> allProducts;
  final Function(Product) onSelected;

  const _ProductSearchDialog({required this.allProducts, required this.onSelected});

  @override
  State<_ProductSearchDialog> createState() => _ProductSearchDialogState();
}

class _ProductSearchDialogState extends State<_ProductSearchDialog> {
  final _searchCtrl = TextEditingController();
  List<Product> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.allProducts;
    _searchCtrl.addListener(() {
      setState(() {
        _filtered = widget.allProducts.where((p) => p.namaProduk.toLowerCase().contains(_searchCtrl.text.toLowerCase())).toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Pilih Barang'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search), 
                hintText: 'Cari nama produk...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final p = _filtered[index];
                  return ListTile(
                    title: Text(p.namaProduk, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Stok Saat Ini: ${p.totalStok} | HPP Master: Rp ${p.hargaBeli}'),
                    onTap: () => widget.onSelected(p),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}