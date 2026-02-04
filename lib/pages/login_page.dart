import 'package:flutter/material.dart';
// Import Database Helper
import '../../database_helper.dart';
// Import Model User
import '../../models/user_model.dart';
// Import Halaman Dashboard
import 'admin/admin_dashboard.dart';
import 'kasir/kasir_dashboard.dart';
import 'owner/owner_dashboard.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false; // Untuk menampilkan loading saat proses login

    // FUNGSI LOGIN
  void _login() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final db = await DatabaseHelper.instance.database;
      
      // QUERY DATABASE: Cari user berdasarkan username
      final List<Map<String, dynamic>> result = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: [_usernameController.text],
      );

      // Cek apakah widget masih ada di layar sebelum pakai context
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      // Cek apakah user ditemukan
      if (result.isNotEmpty) {
        User user = User.fromMap(result.first);

        // Cek apakah password cocok
        if (user.password == _passwordController.text) {
          
          // Gunakan if (mounted) sebelum Navigator agar aman
          if (mounted) {
            if (user.role == 'admin') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AdminDashboard()),
              );
            } else if (user.role == 'kasir') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const KasirDashboard()),
              );
            } else if (user.role == 'owner') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const OwnerDashboard()),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Password salah!')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Username tidak ditemukan!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.storefront, size: 80, color: Colors.orange),
              const SizedBox(height: 20),
              const Text('TOKO SEMBAKO', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 20),
              
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 30),
              
              // Tampilkan Loading Circle jika sedang proses, jika tidak tombol biasa
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          
                        ),
                        child: const Text('MASUK', style: TextStyle(fontSize: 16)),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}