import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lector QR',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
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
    detectionSpeed: DetectionSpeed.normal,
    // formats: const [BarcodeFormat.qrCode], // opcional
  );

  bool _scanned = false;
  String? scannedCode;
  bool _torchOn = false;
  String? _lastError;

  // Animación de la línea del visor
  late final AnimationController _lineController =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat(reverse: true);

  late final Animation<double> _lineAnim =
      CurvedAnimation(parent: _lineController, curve: Curves.easeInOut);

  static const double _frameSize = 260;

  @override
  void dispose() {
    _lineController.dispose();
    cameraController.dispose();
    super.dispose();
  }

  void _showAlert(String code) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Código QR detectado'),
        content: SelectableText(code),
        actions: [
          TextButton(
            onPressed: () async {
              final raw = code.trim();
              final url = raw.contains('://') ? raw : 'https://$raw';
              final uri = Uri.parse(url);
              try {
                await launchUrl(uri, webOnlyWindowName: '_blank');
              } catch (_) {}
              if (!mounted) return;
              Navigator.of(context).pop();
              setState(() => _scanned = false);
            },
            child: const Text('Abrir enlace'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _scanned = false);
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
              try {
                await cameraController.switchCamera();
                if (!mounted) return;
                setState(() => _torchOn = false);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('No se pudo cambiar de cámara: $e')),
                );
              }
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
                        SnackBar(
                          content: Text('No se pudo activar el flash: $e'),
                        ),
                      );
                    }
                  },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          try {
            await cameraController.stop();
            await cameraController.start();
            setState(() {
              _lastError = null;
              _scanned = false;
            });
          } catch (e) {
            setState(() => _lastError = 'No se pudo reiniciar la cámara: $e');
          }
        },
        icon: const Icon(Icons.videocam),
        label: const Text('Reiniciar cámara'),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // La vista de cámara: en v4 no se usa onPermissionSet aquí.
                MobileScanner(
                  controller: cameraController,
                  onDetect: _handleDetect,
                  fit: BoxFit.cover,
                ),

                // Visor con borde + línea animada
                IgnorePointer(
                  child: Center(
                    child: SizedBox(
                      width: _frameSize,
                      height: _frameSize,
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              border:
                                  Border.all(color: Colors.greenAccent, width: 3),
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
                ),

                if (_lastError != null)
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _lastError!,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
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
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Código detectado: $scannedCode',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18),
                      ),
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
