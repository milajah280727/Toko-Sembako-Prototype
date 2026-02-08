class StockBatch {
  final int? idBatch;
  final int idProduk;
  final int jumlahStok;
  final DateTime tanggalExp;
  final int hargaBeliSatuan;

  StockBatch({
    this.idBatch,
    required this.idProduk,
    required this.jumlahStok,
    required this.tanggalExp,
    required this.hargaBeliSatuan,
  });

  factory StockBatch.fromMap(Map<String, dynamic> map) {
    return StockBatch(
      idBatch: map['id_batch'],
      idProduk: map['id_produk'],
      jumlahStok: map['jumlah_stok'],
      // Handle parsing tanggal yang aman
      tanggalExp: DateTime.parse(map['tanggal_exp']), 
      hargaBeliSatuan: map['harga_beli_satuan'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_batch': idBatch,
      'id_produk': idProduk,
      'jumlah_stok': jumlahStok,
      'tanggal_exp': tanggalExp.toIso8601String(),
      'harga_beli_satuan': hargaBeliSatuan,
    };
  }
}