import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../services/solana_client_service.dart';

class WalletConnectionWidget extends StatelessWidget {
  const WalletConnectionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final solanaService = Provider.of<SolanaClientService>(context, listen: true);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Wallet Connection',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            if (solanaService.isConnected) _buildConnectedState(solanaService, context)
            else _buildDisconnectedState(solanaService, context),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedState(SolanaClientService solanaService, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connected: ${solanaService.publicKey?.substring(0, 8)}...${solanaService.publicKey?.substring(solanaService.publicKey!.length - 8)}',
          style: const TextStyle(color: Colors.green),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => solanaService.disconnect(),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Disconnect Wallet'),
        ),
      ],
    );
  }

  Widget _buildDisconnectedState(SolanaClientService solanaService, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Not connected',
          style: TextStyle(color: Colors.red),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => _importWallet(context, solanaService),
          child: const Text('Import Wallet from File'),
        ),
      ],
    );
  }

  Future<void> _importWallet(BuildContext context, SolanaClientService solanaService) async {
  try {
    print('DEBUG: Opening file picker...');
    
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    print('DEBUG: File picker returned: ${result != null ? "file selected" : "cancelled"}');
    
    if (result != null) {
      final file = result.files.single;
      print('DEBUG: File name: ${file.name}');
      print('DEBUG: File size: ${file.size} bytes');
      print('DEBUG: File path: ${file.path}');
      print('DEBUG: File bytes: ${file.bytes != null ? "exists" : "null"}');
      
      // Read file content from path instead of bytes
      if (file.path != null) {
        try {
          final fileContent = await File(file.path!).readAsString();
          print('DEBUG: File content: ${fileContent.substring(0, fileContent.length > 50 ? 50 : fileContent.length)}...');
          
          final jsonArray = jsonDecode(fileContent) as List<dynamic>;
          print('DEBUG: JSON array length: ${jsonArray.length}');
          
          // Convert JSON array to raw bytes
          final keypairBytes = List<int>.from(jsonArray.cast<int>());
          print('DEBUG: Keypair bytes length: ${keypairBytes.length}');

          // Extract the first 32 bytes as the private key
          if (keypairBytes.length == 64) {
            final privateKeyBytes = keypairBytes.sublist(0, 32);
            print('DEBUG: Private key bytes length: ${privateKeyBytes.length}');
            
            final success = await solanaService.connectFromPrivateKey(privateKeyBytes);
            
            if (success) {
              print('DEBUG: Wallet connection successful!');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Wallet connected successfully!')),
              );
            } else {
              print('DEBUG: Wallet connection failed in service');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to connect wallet. Invalid key file.')),
              );
            }
          } else {
            print('DEBUG: Invalid keypair length: ${keypairBytes.length} (expected 64)');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid keypair format. Expected 64 bytes.')),
            );
          }
        } catch (readError) {
          print('DEBUG: File read error: $readError');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error reading file: $readError')),
          );
        }
      } else {
        print('DEBUG: File path is null');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not access file content')),
        );
      }
    } else {
      print('DEBUG: No file selected (user cancelled)');
    }
  } catch (e) {
    print('DEBUG: Overall error: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error importing wallet: $e')),
    );
  }
}
}