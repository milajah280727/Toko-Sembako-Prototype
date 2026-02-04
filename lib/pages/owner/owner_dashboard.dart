import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../supabase_service.dart';
import '../../models/product_model.dart';
import '../login_page.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, int> _financials = {'income': 0, 'expense': 0, 'profit': 0};
  List<Map<String, dynamic>> _transactions = [];
  List<Product> _lowStockProducts = [];
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    
    final results = await Future.wait([
      SupabaseService().getFinancials(),
      SupabaseService().getAllTransactions(),
      SupabaseService().getLowStockProducts(),
      SupabaseService().getAllLogs(),
    ]);

    setState(() {
      _financials = results[0] as Map<String, int>;
      _transactions = results[1] as List<Map<String, dynamic>>;
      _lowStockProducts = results[2] as List<Product>;
      _logs = results[3] as List<Map<String, dynamic>>;
      _isLoading = false;
    });
  }

  void _showAddExpenseDialog() {
    final ketController = TextEditingController();
    final nomController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Catat Pengeluaran'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: ketController, decoration: const InputDecoration(labelText: 'Keterangan (Misal: Beli Plastik)')),
            TextField(controller: nomController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nominal')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (ketController.text.isEmpty || nomController.text.isEmpty) return;
              await SupabaseService().addExpense(ketController.text, int.parse(nomController.text));
              Navigator.pop(context);
              _loadAllData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengeluaran tercatat')));
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // --- DIALOG 1: DETAIL TRANSAKSI ---
  void _showTransactionDetail(Map<String, dynamic> trans) async {
    // Tampilkan loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingContext) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Ambil detail item produk
      final details = await SupabaseService().getTransactionDetails(trans['id_transaksi']);
      
      // Tutup dialog loading (Kita pakai context utama untuk pop yang paling atas)
      if (mounted) Navigator.pop(context); 

      // Ambil data user
      final userData = trans['users'];
      final namaUser = userData != null ? userData['nama_lengkap'] : 'Unknown';

      // Tampilkan dialog detail
      if (mounted) {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Detail Transaksi'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // PROFIL KASIR
                    Card(
                      color: Colors.orange[50],
                      child: ListTile(
                        leading: const Icon(Icons.person, color: Colors.orange),
                        title: Text('Kasir: $namaUser'),
                        subtitle: Text('Waktu: ${trans['tanggal'].toString().split('.')[0]}'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(),
                    const Text('Barang yang Dibeli:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    
                    // LIST DETAIL PRODUK
                    ...details.map((detail) {
                      final prod = detail['produk'];
                      return ListTile(
                        title: Text(prod != null ? prod['nama_produk'] : 'Produk Terhapus'),
                        subtitle: Text('${detail['qty']} x Rp ${prod != null ? prod['harga_jual'] : 0}'),
                        trailing: Text('Rp ${detail['subtotal']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      );
                    }).toList(),
                    
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Bayar:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('Rp ${trans['total_bayar']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Tutup'),
              )
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Tutup loading jika error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat detail: $e')));
      }
    }
  }

  // --- DIALOG 2: DETAIL LOG ---
  void _showLogDetail(Map<String, dynamic> log) {
    final userData = log['users'];
    final namaUser = userData != null ? userData['nama_lengkap'] : 'Unknown';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Detail Aktivitas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PROFIL ADMIN/KASIR
            Card(
              color: Colors.blue[50],
              child: ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: Colors.blue),
                title: Text('Dilakukan Oleh: $namaUser'),
                // Perbaikan String Interpolation
                subtitle: Text('Waktu: ${DateTime.parse(log['waktu']).toLocal().toString().split('.')[0]}'),
              ),
            ),
            const SizedBox(height: 15),
            const Text('Aktivitas:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              width: double.infinity,
              child: Text(
                log['aktivitas'],
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Tutup'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Owner'),
        backgroundColor: Colors.orange,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Keuangan', icon: Icon(Icons.account_balance_wallet)),
            Tab(text: 'Riwayat', icon: Icon(Icons.history)),
            Tab(text: 'Log', icon: Icon(Icons.list_alt)),
            Tab(text: 'Stok Menipis', icon: Icon(Icons.warning_amber)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAllData),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage())))
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildKeuanganTab(),
                _buildRiwayatTab(),
                _buildLogTab(),
                _buildStokTab(),
              ],
            ),
    );
  }

  Widget _buildKeuanganTab() {
    final formatCurrency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(color: Colors.green[50], child: ListTile(leading: const Icon(Icons.trending_up, color: Colors.green), title: const Text('Total Pendapatan'), subtitle: Text(formatCurrency.format(_financials['income'])))),
          Card(color: Colors.red[50], child: ListTile(leading: const Icon(Icons.trending_down, color: Colors.red), title: const Text('Total Pengeluaran'), subtitle: Text(formatCurrency.format(_financials['expense'])))),
          Card(color: Colors.blue[50], child: ListTile(leading: const Icon(Icons.account_balance, color: Colors.blue), title: const Text('Laba Bersih', style: TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(formatCurrency.format(_financials['profit'])))),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _showAddExpenseDialog, icon: const Icon(Icons.add_circle), label: const Text('Catat Pengeluaran Baru'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white)))
        ],
      ),
    );
  }

  Widget _buildRiwayatTab() {
    return _transactions.isEmpty
        ? const Center(child: Text('Belum ada transaksi'))
        : ListView.builder(
            itemCount: _transactions.length,
            itemBuilder: (context, index) {
              final trans = _transactions[index];
              final namaKasir = trans['users'] != null ? trans['users']['nama_lengkap'] : 'Unknown';

              return Card(
                margin: const EdgeInsets.all(8),
                child: InkWell(
                  onTap: () => _showTransactionDetail(trans),
                  child: ListTile(
                    title: Text('Rp ${trans['total_bayar']}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kasir: $namaKasir'),
                        Text('Waktu: ${trans['tanggal'].toString().split('.')[0]}'),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
              );
            },
          );
  }

  Widget _buildLogTab() {
    return _logs.isEmpty
        ? const Center(child: Text('Belum ada aktivitas tercatat'))
        : ListView.builder(
            itemCount: _logs.length,
            itemBuilder: (context, index) {
              final log = _logs[index];
              final namaUser = log['users'] != null ? log['users']['nama_lengkap'] : 'Unknown';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: InkWell(
                  onTap: () => _showLogDetail(log),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.verified_user, size: 20), backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                    title: Text(log['aktivitas'], style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Oleh: $namaUser'),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
              );
            },
          );
  }

  Widget _buildStokTab() {
    return _lowStockProducts.isEmpty
        ? const Center(child: Text('Stok aman, tidak ada barang menipis.'))
        : ListView.builder(
            itemCount: _lowStockProducts.length,
            itemBuilder: (context, index) {
              final product = _lowStockProducts[index];
              return Card(
                color: Colors.orange[100], 
                margin: const EdgeInsets.all(8), 
                child: ListTile(
                  leading: const Icon(Icons.warning, color: Colors.red),
                  title: Text(product.namaProduk, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Kategori: ${product.kategori}'),
                  trailing: Text('Sisa: ${product.stok}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18))
                ),
              );
            },
          );
  }
}