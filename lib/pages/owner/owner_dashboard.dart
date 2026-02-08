import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tokosembakovawal/supabase_service.dart';
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
  
  // Data Asli
  Map<String, int> _financials = {'income': 0, 'expense': 0, 'profit': 0};
  List<Map<String, dynamic>> _transactions = [];
  List<Product> _lowStockProducts = [];
  List<Product> _expiringProducts = []; // VARIABEL BARU: Produk Kadaluarsa
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  // Variabel Pencarian
  final TextEditingController _searchController = TextEditingController();
  int _activeTabIndex = 0;

  // Data Hasil Filter
  late List<Map<String, dynamic>> _filteredTransactions;
  late List<Map<String, dynamic>> _filteredLogs;
  late List<Product> _filteredLowStock;
  late List<Product> _filteredExpiring; // Filter untuk kadaluarsa

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    _tabController.addListener(() {
      setState(() {
        _activeTabIndex = _tabController.index;
      });
      _filterData();
    });

    _searchController.addListener(() {
      _filterData();
    });

    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    
    // Tambahkan pemanggilan getExpiringProducts di sini
    final results = await Future.wait([
      SupabaseService().getFinancials(),
      SupabaseService().getAllTransactions(),
      SupabaseService().getLowStockProducts(),
      SupabaseService().getAllLogs(),
      SupabaseService().getExpiringProducts(), // DATA BARU
    ]);

    setState(() {
      _financials = results[0] as Map<String, int>;
      _transactions = results[1] as List<Map<String, dynamic>>;
      _lowStockProducts = results[2] as List<Product>;
      _logs = results[3] as List<Map<String, dynamic>>;
      _expiringProducts = results[4] as List<Product>; // SIMPAN DATA BARU
      
      // Init filtered lists
      _filteredTransactions = List.from(_transactions);
      _filteredLogs = List.from(_logs);
      _filteredLowStock = List.from(_lowStockProducts);
      _filteredExpiring = List.from(_expiringProducts); // Init filter baru
      
      _isLoading = false;
    });
  }

  void _filterData() {
    String query = _searchController.text.toLowerCase();

    setState(() {
      switch (_activeTabIndex) {
        case 0: // Keuangan
          break;
        case 1: // Riwayat
          if (query.isEmpty) {
            _filteredTransactions = List.from(_transactions);
          } else {
            _filteredTransactions = _transactions.where((item) {
              final namaKasir = item['users'] != null ? item['users']['nama_lengkap'].toLowerCase() : '';
              final total = item['total_bayar'].toString();
              return namaKasir.contains(query) || total.contains(query);
            }).toList();
          }
          break;
        case 2: // Log
          if (query.isEmpty) {
            _filteredLogs = List.from(_logs);
          } else {
            _filteredLogs = _logs.where((item) {
              final aktivitas = item['aktivitas'].toLowerCase();
              final namaUser = item['users'] != null ? item['users']['nama_lengkap'].toLowerCase() : '';
              return aktivitas.contains(query) || namaUser.contains(query);
            }).toList();
          }
          break;
        case 3: // Stok (Sekarang ada 2 kategori: Menipis & Kadaluarsa)
          // Kita filter kedua list berdasarkan pencarian
          if (query.isEmpty) {
            _filteredLowStock = List.from(_lowStockProducts);
            _filteredExpiring = List.from(_expiringProducts);
          } else {
            _filteredLowStock = _lowStockProducts.where((item) => item.namaProduk.toLowerCase().contains(query)).toList();
            _filteredExpiring = _expiringProducts.where((item) => item.namaProduk.toLowerCase().contains(query)).toList();
          }
          break;
      }
    });
  }

  void _showAddExpenseDialog() {
    final ketController = TextEditingController();
    final nomController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Catat Pengeluaran'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ketController, 
              decoration: InputDecoration(
                labelText: 'Keterangan',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              )
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nomController, 
              keyboardType: TextInputType.number, 
              decoration: InputDecoration(
                labelText: 'Nominal',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              )
            ),
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

  void _showTransactionDetail(Map<String, dynamic> trans) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingContext) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final details = await SupabaseService().getTransactionDetails(trans['id_transaksi']);
      
      if (mounted) Navigator.pop(context); 

      final userData = trans['users'];
      final namaUser = userData != null ? userData['nama_lengkap'] : 'Unknown';

      if (mounted) {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Detail Transaksi'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Card(color: Colors.orange[50], child: ListTile(
                      leading: const Icon(Icons.person, color: Colors.orange),
                      title: Text('Kasir: $namaUser'),
                      subtitle: Text('Waktu: ${trans['tanggal'].toString().split('.')[0]}'),
                    )),
                    const SizedBox(height: 10),
                    const Divider(),
                    const Text('Barang yang Dibeli:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    
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
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat detail: $e')));
      }
    }
  }

  void _showLogDetail(Map<String, dynamic> log) {
    final userData = log['users'];
    final namaUser = userData != null ? userData['nama_lengkap'] : 'Unknown';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Detail Aktivitas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.blue[50],
              child: ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: Colors.blue),
                title: Text('Dilakukan Oleh: $namaUser'),
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
              child: Text(log['aktivitas'], style: const TextStyle(fontSize: 14)),
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Dashboard Owner'),
        backgroundColor: Colors.orange,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          isScrollable: false,
          tabs: const [
            Tab(text: 'Keuangan', icon: Icon(Icons.account_balance_wallet)),
            Tab(text: 'Riwayat', icon: Icon(Icons.history)),
            Tab(text: 'Log', icon: Icon(Icons.list_alt)),
            Tab(text: 'Stok', icon: Icon(Icons.warning_amber)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAllData),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage())))
        ],
      ),
      body: Column(
        children: [
          if (_activeTabIndex != 0)
            Container(
              color: Colors.orange,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5, offset: Offset(0, 3))],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: _activeTabIndex == 3 ? 'Cari stok / kadaluarsa...' :
                                _activeTabIndex == 1 ? 'Cari riwayat...' :
                                                  'Cari log aktivitas...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ),
            ),

          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildKeuanganTab(),
                      _buildRiwayatTab(),
                      _buildLogTab(),
                      _buildStokTab(), // TAB STOK DIPERBARUI
                    ],
                  ),
          ),
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
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: Colors.green[50], 
            child: ListTile(
              leading: const Icon(Icons.trending_up, color: Colors.green), 
              title: const Text('Total Pendapatan'), 
              subtitle: Text(formatCurrency.format(_financials['income']))
            )
          ),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: Colors.red[50], 
            child: ListTile(
              leading: const Icon(Icons.trending_down, color: Colors.red), 
              title: const Text('Total Pengeluaran'), 
              subtitle: Text(formatCurrency.format(_financials['expense']))
            )
          ),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: Colors.blue[50], 
            child: ListTile(
              leading: const Icon(Icons.account_balance, color: Colors.blue), 
              title: const Text('Laba Bersih', style: TextStyle(fontWeight: FontWeight.bold)), 
              subtitle: Text(formatCurrency.format(_financials['profit']))
            )
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, 
            child: ElevatedButton.icon(
              onPressed: _showAddExpenseDialog, 
              icon: const Icon(Icons.add_circle), 
              label: const Text('Catat Pengeluaran Baru'), 
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, 
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              )
            )
          )
        ],
      ),
    );
  }

  Widget _buildRiwayatTab() {
    return _filteredTransactions.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 60, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text(_transactions.isEmpty ? 'Belum ada transaksi' : 'Riwayat tidak ditemukan', style: const TextStyle(color: Colors.grey)),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _filteredTransactions.length,
            itemBuilder: (context, index) {
              final trans = _filteredTransactions[index];
              final namaKasir = trans['users'] != null ? trans['users']['nama_lengkap'] : 'Unknown';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: InkWell(
                  onTap: () => _showTransactionDetail(trans),
                  child: ListTile(
                    title: Text('Rp ${trans['total_bayar']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kasir: $namaKasir', style: const TextStyle(fontSize: 12)),
                        Text('Waktu: ${trans['tanggal'].toString().split('.')[0]}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
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
    return _filteredLogs.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_toggle_off, size: 60, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text(_logs.isEmpty ? 'Belum ada aktivitas tercatat' : 'Log tidak ditemukan', style: const TextStyle(color: Colors.grey)),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _filteredLogs.length,
            itemBuilder: (context, index) {
              final log = _filteredLogs[index];
              final namaUser = log['users'] != null ? log['users']['nama_lengkap'] : 'Unknown';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: InkWell(
                  onTap: () => _showLogDetail(log),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.verified_user, size: 20), 
                      backgroundColor: Colors.blueAccent, 
                      foregroundColor: Colors.white
                    ),
                    title: Text(log['aktivitas'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text('Oleh: $namaUser', style: const TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
              );
            },
          );
  }

  // --- TAB STOK YANG DIPERBARUI ---
  Widget _buildStokTab() {
    // Cek apakah ada data sama sekali
    final hasData = _filteredExpiring.isNotEmpty || _filteredLowStock.isNotEmpty;

    if (!hasData) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 10),
            const Text('Stok aman, tidak ada peringatan.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        // 1. BAGIAN KADALUARSA (Prioritas Tinggi)
        if (_filteredExpiring.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
            child: Text(
              '⚠️ PERINGATAN KADALUARSA (7 Hari)',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 14),
            ),
          ),
          ..._filteredExpiring.map((product) {
            // Hitung selisih hari
            final daysLeft = product.nearestExpDate!.difference(DateTime.now()).inDays;
            final isExpired = daysLeft < 0;
            
            return Card(
              color: isExpired ? Colors.red.shade100 : Colors.orange.shade50, 
              margin: const EdgeInsets.symmetric(vertical: 4), 
              child: ListTile(
                leading: const Icon(Icons.timer, color: Colors.red),
                title: Text(product.namaProduk, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Kategori: ${product.kategori}'),
                trailing: Text(
                  isExpired ? 'Kadaluarsa!' : '$daysLeft Hari Lagi',
                  style: TextStyle(
                    color: isExpired ? Colors.red : Colors.deepOrange, 
                    fontWeight: FontWeight.bold, 
                    fontSize: 14
                  ),
                ),
              ),
            );
          }).toList(),
          
          const Divider(height: 30),
        ],

        // 2. BAGIAN STOK MENIPIS (Prioritas Sedang)
        if (_filteredLowStock.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
            child: Text(
              '📉 STOK MENIPIS',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 14),
            ),
          ),
          ..._filteredLowStock.map((product) {
            return Card(
              color: Colors.yellow[50], 
              margin: const EdgeInsets.symmetric(vertical: 4), 
              child: ListTile(
                leading: const Icon(Icons.inventory, color: Colors.orange),
                title: Text(product.namaProduk, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Kategori: ${product.kategori}'),
                trailing: Text('Sisa: ${product.totalStok}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16))
              ),
            );
          }).toList(),
        ],
      ],
    );
  }
}