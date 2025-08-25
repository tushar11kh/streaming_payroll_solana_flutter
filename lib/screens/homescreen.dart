import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:streaming_payroll_solana_flutter/services/solana_client_service.dart';
import 'package:provider/provider.dart';
import 'package:solana/solana.dart';

class Homescreen extends StatefulWidget {
  const Homescreen({super.key});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  Ed25519HDPublicKey? _publicKey;
  bool _isValidKey = false;
  String _validationMessage = 'No key imported';
  bool _isLoading = false;

  Future<void> _importWallet(BuildContext context, SolanaClientService solanaService) async {
    try {
      print('DEBUG: Opening file picker...');
      setState(() {
        _isLoading = true;
        _validationMessage = 'Importing wallet...';
      });
      
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      print('DEBUG: File picker returned: ${result != null ? "file selected" : "cancelled"}');
      
      if (result != null) {
        final file = result.files.single;
        print('DEBUG: File name: ${file.name}');
        print('DEBUG: File size: ${file.size} bytes');
        
        // Handle both path and bytes
        Uint8List fileBytes;
        if (file.bytes != null) {
          fileBytes = file.bytes!;
        } else if (file.path != null) {
          fileBytes = await File(file.path!).readAsBytes();
        } else {
          throw Exception('Could not access file content');
        }

        // Parse as JSON array (standard Solana keypair format)
        final fileContent = utf8.decode(fileBytes);
        print('DEBUG: File content: ${fileContent.substring(0, fileContent.length > 50 ? 50 : fileContent.length)}...');
        
        final jsonArray = jsonDecode(fileContent) as List<dynamic>;
        print('DEBUG: JSON array length: ${jsonArray.length}');
        
        // Convert JSON array to raw bytes
        final keypairBytes = Uint8List.fromList(jsonArray.cast<int>());
        print('DEBUG: Keypair bytes length: ${keypairBytes.length}');

        // Extract the first 32 bytes as the private key
        if (keypairBytes.length == 64) {
          final privateKeyBytes = keypairBytes.sublist(0, 32);
          print('DEBUG: Private key bytes length: ${privateKeyBytes.length}');
          
          final success = await solanaService.connectFromPrivateKey(privateKeyBytes);
          
          if (success && solanaService.wallet != null) {
            print('DEBUG: Wallet connection successful!');
            
            final actualPublicKey = solanaService.wallet!.publicKey;
            
            setState(() {
              _isValidKey = true;
              _publicKey = actualPublicKey;
              _validationMessage = 'Wallet connected successfully!';
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Wallet connected successfully!')),
            );
          } else {
            print('DEBUG: Wallet connection failed in service');
            _resetToInitialState('Failed to connect wallet. Invalid key file.');
          }
        } else {
          print('DEBUG: Invalid keypair length: ${keypairBytes.length} (expected 64)');
          _resetToInitialState('Invalid keypair format. Expected 64 bytes.');
        }
      } else {
        print('DEBUG: No file selected (user cancelled)');
        setState(() {
          _validationMessage = 'No file selected';
        });
      }
    } catch (e) {
      print('DEBUG: Overall error: $e');
      _resetToInitialState('Invalid key file format. Please use a valid Solana keypair JSON file.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _disconnectWallet(SolanaClientService solanaService) {
    // Placeholder function to disconnect wallet
    // In a real implementation, this would clear the wallet from the service
    solanaService.disconnect();
    
    setState(() {
      _isValidKey = false;
      _publicKey = null;
      _validationMessage = 'Wallet disconnected';
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Wallet disconnected')),
    );
  }

  void _resetToInitialState(String errorMessage) {
    setState(() {
      _isValidKey = false;
      _publicKey = null;
      _validationMessage = errorMessage;
    });
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final solanaService = Provider.of<SolanaClientService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solana Payroll - Import Key'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'Import Solana Keypair File',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Select your keypair file (generated with solana-keygen)',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            
            Center(
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _importWallet(context, solanaService),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Import Keypair File', style: TextStyle(fontSize: 16)),
              ),
            ),
            
            const SizedBox(height: 30),
            
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      _isValidKey ? Icons.check_circle : Icons.error,
                      color: _isValidKey ? Colors.green : Colors.orange,
                      size: 30,
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        _validationMessage,
                        style: TextStyle(
                          color: _isValidKey ? Colors.green : Colors.orange,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            if (_publicKey != null) ...[
              const SizedBox(height: 20),
              const Text(
                'Public Key:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          _publicKey.toString(),
                          style: const TextStyle(fontFamily: 'Monospace', fontSize: 12),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () => _copyToClipboard(_publicKey.toString()),
                        tooltip: 'Copy to clipboard',
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
            // Dashboard Section - Only shown after successful validation
            if (_isValidKey) ...[
              const SizedBox(height: 40),
              const Center(
                child: Text(
                  'Dashboard',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
              
              // Employer and Employee Cards
              // Use a ConstrainedBox to limit the height on smaller screens
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: Row(
                  children: [
                    // Employer Card
                    Expanded(
                      child: Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.business_center,
                                size: 50,
                                color: Colors.blue[700],
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Employer',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Manage payroll, add employees, and process payments',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 15),
                              ElevatedButton(
                                onPressed: () {
                                  // Navigate to employer dashboard
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[700],
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Employer Dashboard'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 20),
                    
                    // Employee Card
                    Expanded(
                      child: Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.green[700],
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Employee',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'View payment history, track hours, and manage profile',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 15),
                              ElevatedButton(
                                onPressed: () {
                                  // Navigate to employee dashboard
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[700],
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Employee Dashboard'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Disconnect Wallet Button
              const SizedBox(height: 30),
              Center(
                child: ElevatedButton(
                  onPressed: () => _disconnectWallet(solanaService),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Disconnect Wallet', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}