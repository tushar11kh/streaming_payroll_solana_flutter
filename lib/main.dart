import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:streaming_payroll_solana_flutter/screens/homescreen.dart';
import 'services/solana_client_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
        return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SolanaClientService()),
      ],
      child: MaterialApp(
        title: 'Solana Streaming Payroll',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const Homescreen(),
      ),
    );
  }
}

