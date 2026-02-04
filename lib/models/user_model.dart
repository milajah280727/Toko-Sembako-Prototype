class User {
  final int? id;
  final String username;
  final String password;
  final String role;
  final String namaLengkap;

  User({
    this.id,
    required this.username,
    required this.password,
    required this.role,
    required this.namaLengkap,
  });

  // Fungsi untuk mengubah data dari Database (Map) menjadi Object User
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id_user'],
      username: map['username'],
      password: map['password'],
      role: map['role'],
      namaLengkap: map['nama_lengkap'],
    );
  }
}