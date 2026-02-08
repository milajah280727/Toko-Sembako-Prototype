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
    return {'income': income, 'expense': expense, 'profit': income - expense};
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
  Future<List<Map<String, dynamic>>> getTransactionDetails(
    int idTransaksi,
  ) async {
    final response = await supabase
        .from('detail_transaksi')
        .select(
          '*, produk(*)',
        ) // Join dengan tabel produk untuk ambil nama dan harga
        .eq('id_transaksi', idTransaksi);
    return response;
  }

  // --- FUNGSI BARU: AMBIL PRODUK YANG AKAN KADALUARSA ---
  // Mengambil produk yang tanggal kadaluarsanya <= 7 hari ke depan
  Future<List<Product>> getExpiringProducts() async {
    // Hitung tanggal 7 hari dari sekarang
    final sevenDaysFromNow = DateTime.now().add(const Duration(days: 7));

    final response = await supabase
        .from('produk')
        .select()
        .lte(
          'tanggal_kadaluarsa',
          sevenDaysFromNow.toIso8601String(),
        ) // Less than or equal to 7 days
        .order('tanggal_kadaluarsa');

    // Filter di sisi Dart untuk memastikan tanggal tidak null (jika ada data kosong di DB)
    return response
        .where((json) => json['tanggal_kadaluarsa'] != null)
        .map((json) => Product.fromMap(json))
        .toList();
  }

  // --- FITUR PEMBELIAN / RESTOCK ---

  // Fungsi untuk mencatat pembelian barang masuk
  Future<void> addPurchaseOrder({
    required int idUser,
    required String supplier,
    required int totalBelanja,
    required String? catatan,
    required List<Map<String, dynamic>>
    items, // List item: {id_produk, qty, harga_beli_satuan, subtotal}
  }) async {
    try {
      // 1. Simpan Header Pembelian
      final result = await supabase.from('pembelian').insert({
        'id_user': idUser,
        'supplier': supplier,
        'total_beli': totalBelanja,
        'catatan': catatan,
      }).select();

      final idPembelian = result.first['id_pembelian'];

      // 2. Loop setiap item untuk simpan detail & update stok
      for (var item in items) {
        // A. Simpan Detail Pembelian
        await supabase.from('detail_pembelian').insert({
          'id_pembelian': idPembelian,
          'id_produk': item['id_produk'],
          'qty': item['qty'],
          'harga_beli_satuan': item['harga_beli_satuan'],
          'subtotal': item['subtotal'],
        });

        // B. Update Stok Produk (TAMBAH)
        await supabase.rpc(
          'increment_stok',
          params: {'row_id': item['id_produk'], 'qty_to_add': item['qty']},
        );

        // C. Update Harga Beli Master (HPP) di tabel Produk
        // Kita asumsikan HPP mengikuti harga beli terakhir (Last In Price)
        await supabase
            .from('produk')
            .update({'harga_beli': item['harga_beli_satuan']})
            .eq('id_produk', item['id_produk']);
      }

      // 3. Catat Log
      await supabase.from('log').insert({
        'id_user': idUser,
        'aktivitas':
            'Menerima stok dari supplier: $supplier senilai Rp $totalBelanja',
      });
    } catch (e) {
      print("Error di addPurchaseOrder: $e");
      rethrow;
    }
  }

  // Fungsi untuk menambah stok (Membuat Batch Baru)
  Future<void> addStockBatch({
    required int idProduk,
    required int qty,
    required DateTime tanggalExp,
    required int hargaBeliSatuan,
  }) async {
    // 1. Insert ke tabel stok_batch
    await supabase.from('stok_batch').insert({
      'id_produk': idProduk,
      'jumlah_stok': qty,
      'tanggal_exp': tanggalExp.toIso8601String(),
      'harga_beli_satuan': hargaBeliSatuan,
    });

    // 2. (Opsional) Update HPP Master di tabel produk
    // Misalnya kita ingin HPP master selalu mengikuti harga beli terakhir
    await supabase
        .from('produk')
        .update({'harga_beli': hargaBeliSatuan})
        .eq('id_produk', idProduk);
  }

  // Mengambil Product + Total Stok (Penjumlahan Batch)
  // Mengambil Product + Total Stok (Penjumlahan Batch)
  Future<List<Product>> getProductsWithStock() async {
    // Ambil semua master produk dulu
    final productsRaw = await supabase.from('produk').select('*');

    List<Product> resultProducts = [];

    for (var p in productsRaw) {
      // 1. Hitung total stok dari tabel stok_batch
      final batchRes = await supabase
          .from('stok_batch')
          .select('jumlah_stok')
          .eq('id_produk', p['id_produk']);

      int totalStok = batchRes.fold(
        0,
        (sum, item) => sum + (item['jumlah_stok'] as int),
      );

      // 2. Cari tanggal exp terdekat (FEFO)
      final batchExp = await supabase
          .from('stok_batch')
          .select('tanggal_exp')
          .eq('id_produk', p['id_produk'])
          .order('tanggal_exp', ascending: true)
          .limit(1);

      DateTime? nearestExp = batchExp.isNotEmpty
          ? DateTime.parse(batchExp.first['tanggal_exp'])
          : null;

      // 3. Gabungkan data master + data kalkulasi ke dalam Map sementara
      Map<String, dynamic> combinedMap = Map.from(p);
      combinedMap['total_stok'] = totalStok;
      combinedMap['nearest_exp'] = nearestExp?.toIso8601String();

      // 4. Jadikan Object Product (Sekarang Product punya stok & exp)
      resultProducts.add(Product.fromMap(combinedMap));
    }
    return resultProducts;
  }

  Future<void> processSaleFEFO({
    required int idProduk,
    required int qtyToSell, // Jumlah yang dibeli customer
  }) async {
    // 1. Ambil semua batch produk ini, urutkan berdasarkan Tanggal Exp (ASC)
    final batches = await supabase
        .from('stok_batch')
        .select()
        .eq('id_produk', idProduk)
        .order('tanggal_exp', ascending: true);

    int remainingQty = qtyToSell;

    // 2. Loop setiap batch (FEFO Logic)
    for (var batchData in batches) {
      if (remainingQty <= 0) break; // Jika sudah terpenuhi, stop

      int currentBatchStock = batchData['jumlah_stok'];
      int batchId = batchData['id_batch'];

      if (currentBatchStock > 0) {
        if (remainingQty <= currentBatchStock) {
          // Kasus A: Stok batch ini cukup
          int newStock = currentBatchStock - remainingQty;
          await supabase
              .from('stok_batch')
              .update({'jumlah_stok': newStock})
              .eq('id_batch', batchId);
          remainingQty = 0; // Kebutuhan terpenuhi
        } else {
          // Kasus B: Stok batch ini tidak cukup, habiskan saja!
          await supabase.from('stok_batch').delete().eq('id_batch', batchId);
          remainingQty -=
              currentBatchStock; // Kurangi kebutuhan, lanjut ke batch berikutnya
        }
      }
    }

    if (remainingQty > 0) {
      throw Exception(
        "Stok fisik tidak mencukupi meskipun total stok cukup! (Terjadi karena fragmentasi batch) - Ini jarang terjadi tapi harus dihandle.",
      );
    }
  }
}
