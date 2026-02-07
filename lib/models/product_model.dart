class Product {
  final int? id;
  final String namaProduk;
  final String kategori;
  final int hargaJual;
  int stok;
  final String barcode;
  final String? gambar; // TAMBAHKAN INI

  Product({
    this.id,
    required this.namaProduk,
    required this.kategori,
    required this.hargaJual,
    required this.stok,
    this.barcode = '',
    this.gambar, // TAMBAHKAN INI
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id_produk'],
      namaProduk: map['nama_produk'],
      kategori: map['kategori'],
      hargaJual: map['harga_jual'],
      stok: map['stok'],
      barcode: map['barcode'] ?? '',
      gambar: map['gambar'], // TAMBAHKAN INI
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_produk': id,
      'nama_produk': namaProduk,
      'kategori': kategori,
      'harga_jual': hargaJual,
      'stok': stok,
      'barcode': barcode,
      'gambar': gambar, // TAMBAHKAN INI
    };
  }
}