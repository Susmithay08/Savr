import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  bool _isScanning = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Barcode')),
      body: MobileScanner(
        onDetect: (capture) {
          if (!_isScanning) return;

          final Barcode barcode = capture.barcodes.first;
          final String? barcodeValue = barcode.rawValue;

          if (barcodeValue != null) {
            setState(() => _isScanning = false);
            Navigator.pop(context, barcodeValue);
          }
        },
      ),
    );
  }
}
