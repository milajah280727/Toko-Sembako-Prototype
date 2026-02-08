class Product {
  final int? id;
  final String namaProduk;
  final String kategori;
  final int hargaJual;
  final String barcode;
  final String? gambar;
  final int hargaBeli; 
  
  // --- TAMBAHKAN INI KEMBALI (Untuk keperluan Tampilan UI) ---
  // Field ini tidak akan disimpan ke DB, tapi diisi oleh fungsi getProductsWithStock
  final int totalStok; 
  final DateTime? nearestExpDate; 

  Product({
    this.id,
    required this.namaProduk,
    required this.kategori,
    required this.hargaJual,
    this.barcode = '',
    this.gambar,
    required this.hargaBeli,
    required this.totalStok,      // Default 0
    this.nearestExpDate,         // Default null
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id_produk'],
      namaProduk: map['nama_produk'],
      kategori: map['kategori'],
      hargaJual: map['harga_jual'],
      barcode: map['barcode'] ?? '',
      gambar: map['gambar'],
      hargaBeli: map['harga_beli'] ?? 0,
      // Ambil dari hasil kalkulasi service (key 'total_stok' dan 'nearest_exp')
      totalStok: map['total_stok'] ?? 0, 
      nearestExpDate: map['nearest_exp'] != null ? DateTime.parse(map['nearest_exp']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_produk': id,
      'nama_produk': namaProduk,
      'kategori': kategori,
      'harga_jual': hargaJual,
      'barcode': barcode,
      'gambar': gambar,
      'harga_beli': hargaBeli,
      // totalStok dan nearestExpDate TIDAK perlu dikirim ke DB saat save/update
    };
  }
}