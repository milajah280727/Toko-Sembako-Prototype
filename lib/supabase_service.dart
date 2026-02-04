import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tokosembakovawal/models/product_model.dart';

// Menggunakan singleton
final supabase = Supabase.instance.client;

class SupabaseService {
  // --- LOGIN ---
  Future<List<Map<String, dynamic>>> login(
    String username,
    String password,
  ) async {
    final response = await supabase
        .from('users')
        .select()
        .eq('username', username)
        .eq('password', password);

    return response;
  }

  // --- PRODUK ---
  Future<List<Product>> getAllProducts() async {
    final response = await supabase
        .from('produk')
        .select()
        .order('nama_produk');
    return response.map((json) => Product.fromMap(json)).toList();
  }

  Future<int> createProduct(Map<String, dynamic> data) async {
    // 1. Copy data agar data asli tidak berubah (opsional, tapi aman)
    final dataWithoutId = Map<String, dynamic>.from(data);

    // 2. Hapus key 'id_produk' supaya Database yang mengisinya sendiri (Auto Increment)
    dataWithoutId.remove('id_produk');

    // 3. Kirim data tanpa ID ke Supabase
    await supabase.from('produk').insert(dataWithoutId);

    return 1;
  }

  Future<void> updateProduct(int id, Map<String, dynamic> data) async {
    await supabase.from('produk').update(data).eq('id_produk', id);
  }

  Future<void> deleteProduct(int id) async {
    await supabase.from('produk').delete().eq('id_produk', id);
  }

    // --- FUNGSI TRANSAKSI ---

  Future<void> saveTransaction({
    required int idUser,
    required int totalBayar,
    required int uangDiterima,
    required int kembalian,
    required List<Map<String, dynamic>> items,
  }) async {
    // BARIS ERROR YANG TADI DIHAPUS:
    // final db = await instance.database; 

    // Kita langsung pakai 'supabase' (instance global) di bawah ini

    // 1. Simpan Header Transaksi
    final result = await supabase.from('transaksi').insert({
      'id_user': idUser,
      'total_bayar': totalBayar,
      'uang_diterima': uangDiterima,
      'kembalian': kembalian,
    }).select(); // select() agar mendapatkan ID transaksi yang baru dibuat

    final idTransaksi = result.first['id_transaksi'];

    // 2. Loop Detail & Update Stok (Metode Aman: Fetch -> Update)
    for (var item in items) {
      // A. Insert Detail Transaksi
      await supabase.from('detail_transaksi').insert({
        'id_transaksi': idTransaksi,
        'id_produk': item['id_produk'],
        'qty': item['qty'],
        'subtotal': item['subtotal'],
      });

      // B. Update Stok Produk (Mengambil data stok terlebih dahulu)
      final productData = await supabase
          .from('produk')
          .select('stok')
          .eq('id_produk', item['id_produk'])
          .single();

      final currentStok = productData['stok'] as int;
      final newStok = currentStok - (item['qty'] as int);

      await supabase
          .from('produk')
          .update({'stok': newStok})
          .eq('id_produk', item['id_produk']);
    }

    // 3. Catat Log
    await supabase.from('log').insert({
      'id_user': idUser,
      'aktivitas': 'Melakukan transaksi senilai Rp $totalBayar',
    });
  }

  // --- OWNER (Keuangan & Laporan) ---

  Future<Map<String, int>> getFinancials() async {
    
    // 1. Ambil semua total_bayar dari tabel transaksi
    final trans = await supabase.from('transaksi').select('total_bayar');
    
    // Hitung total pendapatan menggunakan 'fold' di Dart
    final income = trans.fold<int>(0, (sum, item) {
      return sum + (item['total_bayar'] as int? ?? 0);
    });

    // 2. Ambil semua nominal dari tabel pengeluaran
    final exp = await supabase.from('pengeluaran').select('nominal');
    
    // Hitung total pengeluaran
    final expense = exp.fold<int>(0, (sum, item) {
      return sum + (item['nominal'] as int? ?? 0);
    });

    // 3. Hitung Laba Bersih
    return {
      'income': income,
      'expense': expense,
      'profit': income - expense,
    };
  }

  Future<List<Product>> getLowStockProducts() async {
    final response = await supabase
        .from('produk')
        .select()
        .lt('stok', 5)
        .order('stok');
    return response.map((json) => Product.fromMap(json)).toList();
  }

  Future<List<Map<String, dynamic>>> getAllTransactions() async {
    // Join query di Supabase
    final response = await supabase
        .from('transaksi')
        .select('*, users(nama_lengkap)')
        .order('tanggal', ascending: false);
    return response;
  }

  Future<void> addExpense(String ket, int nominal) async {
    await supabase.from('pengeluaran').insert({
      'keterangan': ket,
      'nominal': nominal,
    });
  }

    // --- LOG ---
  // Fungsi mengambil semua log dan join dengan user
  Future<List<Map<String, dynamic>>> getAllLogs() async {
    final response = await supabase
        .from('log')
        .select('*, users(nama_lengkap)') // Join tabel users
        .order('waktu', ascending: false); // Yang paling baru di atas
    return response;
  }

    // Fungsi mencatat aktivitas manual (untuk dipanggil di halaman admin/kasir)
  Future<void> addLog(int userId, String aktivitas) async {
    await supabase.from('log').insert({
      'id_user': userId,
      'aktivitas': aktivitas,
      // Kolom 'waktu' diisi otomatis oleh database (default now())
    });
  }

    // --- FUNGSI DETAIL TRANSAKSI ---
  
  // Mengambil detail item (produk yang dibeli) berdasarkan ID Transaksi
  Future<List<Map<String, dynamic>>> getTransactionDetails(int idTransaksi) async {
    final response = await supabase
        .from('detail_transaksi')
        .select('*, produk(*)') // Join dengan tabel produk untuk ambil nama dan harga
        .eq('id_transaksi', idTransaksi);
    return response;
  }

}
