import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;


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

class _QRScannerPageState extends State<QRScannerPage>
    with SingleTickerProviderStateMixin {
  final MobileScannerController cameraController = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _scanned = false;
  String? scannedCode;
  bool _torchOn = false;

  late final AnimationController _lineController =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat(reverse: true);
  late final Animation<double> _lineAnim =
      CurvedAnimation(parent: _lineController, curve: Curves.easeInOut);

  static const double _frameSize = 260;

void _showAlert(String code) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Código QR detectado'),
      content: SelectableText(code),
      actions: [
        // Botón para abrir si es link
TextButton(
  onPressed: () {
    final raw = code.trim();
    final url = raw.contains('://') ? raw : 'https://$raw';

    // Abre en nueva pestaña
    web.window.open(url, '_blank');

    Navigator.of(context).pop();
    setState(() => _scanned = false);
  },
  child: const Text('Abrir enlace'),
),

        // Botón de cerrar
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            setState(() => _scanned = false); // permitir nuevo escaneo
          },
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}


  void _handleDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final codes = capture.barcodes;
    final code = codes.isNotEmpty ? codes.first.rawValue : null;
    if (code != null) {
      setState(() {
        _scanned = true;
        scannedCode = code;
      });
      _showAlert(code);
    }
  }

  @override
  void dispose() {
    _lineController.dispose();
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lector QR con visor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            tooltip: 'Cambiar cámara',
            onPressed: () async {
              await cameraController.switchCamera();
              if (!mounted) return;
              setState(() => _torchOn = false);
            },
          ),
          IconButton(
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
            tooltip: kIsWeb ? 'Flash no soportado en Web' : 'Flash',
            onPressed: kIsWeb
                ? null
                : () async {
                    try {
                      await cameraController.toggleTorch();
                      if (!mounted) return;
                      setState(() => _torchOn = !_torchOn);
                    } catch (e) {
                      if (!mounted) return;
                      setState(() => _torchOn = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('No se pudo activar el flash: $e')),
                      );
                    }
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Cámara
                MobileScanner(
                  controller: cameraController,
                  onDetect: _handleDetect,
                  fit: BoxFit.cover,
                ),

                // Visor con borde + línea animada
                Center(
                  child: SizedBox(
                    width: _frameSize,
                    height: _frameSize,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Colors.greenAccent, width: 3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _lineAnim,
                          builder: (_, __) {
                            final y = (_frameSize - 4) * _lineAnim.value;
                            return Positioned(
                              top: y,
                              left: 8,
                              right: 8,
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Colors.transparent,
                                      theme.colorScheme.secondary
                                          .withOpacity(0.9),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Texto guía
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Text(
                    'Alinea el código dentro del recuadro',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: scannedCode != null
                  ? Text(
                      'Código detectado: $scannedCode',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18),
                    )
                  : const Text(
                      'Escanea un código QR',
                      style: TextStyle(fontSize: 18),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
