import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tokosembakovawal/pages/login_page.dart';


void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    // MASUKKAN URL & ANON KEY DARI DASHBOARD SUPABASE
    url: 'https://zwlczviupdfmiepwnqgo.supabase.co', 
    anonKey: 'sb_publishable_XJirj-XDXIODf5R9655y9w_p4LAJtSU',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Toko Sembako App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const LoginPage(), // Panggil LoginPage di sini
    );
  }
}