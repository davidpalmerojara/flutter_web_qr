import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lector QR',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const QRScannerPage(),
    );
  }
}

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final MobileScannerController cameraController = MobileScannerController();
  bool _scanned = false;
  String? scannedCode;

  void _showAlert(String code) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Código QR detectado'),
        content: Text(code),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _scanned = false; // Permite escanear de nuevo
              });
            },
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lector QR Web (mobile_scanner)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: MobileScanner(
              controller: cameraController,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                final String? code = barcodes.isNotEmpty ? barcodes.first.rawValue : null;

                if (!_scanned && code != null) {
                  setState(() {
                    _scanned = true;
                    scannedCode = code;
                  });
                  _showAlert(code);
                }
              },
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                scannedCode != null
                    ? 'Código detectado: $scannedCode'
                    : 'Escanea un código QR',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}
