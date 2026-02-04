import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:tokosembakovawal/models/product_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sembako.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // VERSI DIUBAH MENJADI 2 Karena ada tabel baru (pengeluaran)
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  // Fungsi ini dipanggil saat versi database ditingkatkan (misal user sudah install app lama)
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Jika versi lama 1, tambahkan tabel pengeluaran
      await db.execute('''
      CREATE TABLE pengeluaran (
        id_pengeluaran INTEGER PRIMARY KEY AUTOINCREMENT,
        keterangan TEXT NOT NULL,
        nominal INTEGER NOT NULL,
        tanggal TEXT NOT NULL
      )
      ''');
    }
  }

  // --- FUNGSI CRUD PRODUK ---

  Future<List<Product>> getAllProducts() async {
    final db = await instance.database;
    final result = await db.query('produk', orderBy: 'nama_produk ASC');
    return result.map((json) => Product.fromMap(json)).toList();
  }

  Future<int> createProduct(Product product) async {
    final db = await instance.database;
    final data = product.toMap();
    data.remove('id_produk');
    return await db.insert('produk', data);
  }

  Future<int> updateProduct(Product product) async {
    final db = await instance.database;
    return await db.update(
      'produk',
      product.toMap(),
      where: 'id_produk = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await instance.database;
    return await db.delete(
      'produk',
      where: 'id_produk = ?',
      whereArgs: [id],
    );
  }

  // --- FUNGSI TRANSAKSI ---

  Future<int> saveTransaction({
    required int idUser,
    required int totalBayar,
    required int uangDiterima,
    required int kembalian,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await instance.database;

    return await db.transaction((txn) async {
      // 1. Simpan Header Transaksi
      final idTransaksi = await txn.insert('transaksi', {
        'id_user': idUser,
        'tanggal': DateTime.now().toIso8601String(),
        'total_bayar': totalBayar,
        'uang_diterima': uangDiterima,
        'kembalian': kembalian,
      });

      // 2. Simpan Detail & Kurangi Stok
      for (var item in items) {
        await txn.insert('detail_transaksi', {
          'id_transaksi': idTransaksi,
          'id_produk': item['id_produk'],
          'qty': item['qty'],
          'subtotal': item['subtotal'],
        });

        await txn.rawUpdate(
          'UPDATE produk SET stok = stok - ? WHERE id_produk = ?',
          [item['qty'], item['id_produk']],
        );
      }

      // 3. Catat Log
      await txn.insert('log', {
        'id_user': idUser,
        'aktivitas': 'Melakukan transaksi senilai Rp $totalBayar',
        'waktu': DateTime.now().toIso8601String(),
      });

      return idTransaksi;
    });
  }

  // --- FUNGSI FITUR OWNER (KEUANGAN & LAPORAN) ---

  // 1. Ambil Data Keuangan (Pendapatan, Pengeluaran, Laba)
  Future<Map<String, int>> getFinancials() async {
    final db = await instance.database;
    
    // Hitung Total Pendapatan
    final incomeResult = await db.rawQuery('SELECT SUM(total_bayar) as total FROM transaksi');
    final income = incomeResult.first['total'] as int? ?? 0;

    // Hitung Total Pengeluaran
    final expenseResult = await db.rawQuery('SELECT SUM(nominal) as total FROM pengeluaran');
    final expense = expenseResult.first['total'] as int? ?? 0;

    return {
      'income': income,
      'expense': expense,
      'profit': income - expense,
    };
  }

  // 2. Tambah Pengeluaran Baru
  Future<int> addExpense(String keterangan, int nominal) async {
    final db = await instance.database;
    return await db.insert('pengeluaran', {
      'keterangan': keterangan,
      'nominal': nominal,
      'tanggal': DateTime.now().toIso8601String(),
    });
  }

  // 3. Cari Produk Stok Menipis (< 5)
  Future<List<Product>> getLowStockProducts() async {
    final db = await instance.database;
    final result = await db.query(
      'produk',
      where: 'stok < ?',
      whereArgs: [5], // Batas minimal stok
      orderBy: 'stok ASC',
    );
    return result.map((json) => Product.fromMap(json)).toList();
  }

  // 4. Ambil Riwayat Transaksi (Join dengan User untuk tampilkan nama kasir)
  Future<List<Map<String, dynamic>>> getAllTransactions() async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT t.*, u.nama_lengkap 
      FROM transaksi t
      JOIN users u ON t.id_user = u.id_user
      ORDER BY t.tanggal DESC
    ''');
    return result;
  }

  // --- FUNGSI MEMBUAT TABEL (SEEDER) ---
  Future _createDB(Database db, int version) async {
    // 1. Users
    await db.execute('''
    CREATE TABLE users (
      id_user INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT NOT NULL UNIQUE,
      password TEXT NOT NULL,
      role TEXT NOT NULL,
      nama_lengkap TEXT NOT NULL
    )
    ''');

    // 2. Produk
    await db.execute('''
    CREATE TABLE produk (
      id_produk INTEGER PRIMARY KEY AUTOINCREMENT,
      nama_produk TEXT NOT NULL,
      kategori TEXT NOT NULL,
      harga_jual INTEGER NOT NULL,
      stok INTEGER NOT NULL
    )
    ''');

    // 3. Transaksi
    await db.execute('''
    CREATE TABLE transaksi (
      id_transaksi INTEGER PRIMARY KEY AUTOINCREMENT,
      id_user INTEGER NOT NULL,
      tanggal TEXT NOT NULL,
      total_bayar INTEGER NOT NULL,
      uang_diterima INTEGER NOT NULL,
      kembalian INTEGER NOT NULL,
      FOREIGN KEY (id_user) REFERENCES users (id_user)
    )
    ''');

    // 4. Detail Transaksi
    await db.execute('''
    CREATE TABLE detail_transaksi (
      id_detail INTEGER PRIMARY KEY AUTOINCREMENT,
      id_transaksi INTEGER NOT NULL,
      id_produk INTEGER NOT NULL,
      qty INTEGER NOT NULL,
      subtotal INTEGER NOT NULL,
      FOREIGN KEY (id_transaksi) REFERENCES transaksi (id_transaksi),
      FOREIGN KEY (id_produk) REFERENCES produk (id_produk)
    )
    ''');

    // 5. Log
    await db.execute('''
    CREATE TABLE log (
      id_log INTEGER PRIMARY KEY AUTOINCREMENT,
      id_user INTEGER NOT NULL,
      aktivitas TEXT NOT NULL,
      waktu TEXT NOT NULL,
      FOREIGN KEY (id_user) REFERENCES users (id_user)
    )
    ''');

    // 6. Pengeluaran (Tabel Baru)
    await db.execute('''
    CREATE TABLE pengeluaran (
      id_pengeluaran INTEGER PRIMARY KEY AUTOINCREMENT,
      keterangan TEXT NOT NULL,
      nominal INTEGER NOT NULL,
      tanggal TEXT NOT NULL
    )
    ''');

    // SEEDER DATA USER
    await db.insert('users', {
      'username': 'admin',
      'password': 'admin',
      'role': 'admin',
      'nama_lengkap': 'Pak Admin'
    });

    await db.insert('users', {
      'username': 'kasir',
      'password': 'kasir',
      'role': 'kasir',
      'nama_lengkap': 'Kak Kasir'
    });

    await db.insert('users', {
      'username': 'owner',
      'password': 'owner',
      'role': 'owner',
      'nama_lengkap': 'Om Owner'
    });

    // SEEDER DATA PRODUK
    await db.insert('produk', {
      'nama_produk': 'Beras Rojolele 5kg',
      'kategori': 'Sembako',
      'harga_jual': 65000,
      'stok': 50
    });
    
    await db.insert('produk', {
      'nama_produk': 'Minyak Goreng 2L',
      'kategori': 'Sembako',
      'harga_jual': 35000,
      'stok': 20
    });
  }
  
  Future close() async {
    final db = await instance.database;
    db.close();
  }
}