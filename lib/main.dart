import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

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
    // Si quieres limitar solo a QR:
    // formats: [BarcodeFormat.qrCode],
  );

  // Evitar múltiples modales a la vez
  bool _showingDialog = false;

  // Estado visual del flash
  bool _torchOn = false;

  // Línea de escaneo (opcional)
  late final AnimationController _lineController =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat(reverse: true);
  late final Animation<double> _lineAnim =
      CurvedAnimation(parent: _lineController, curve: Curves.easeInOut);

  static const double _frameSize = 260;

  // ---------- Helpers URL ----------
  bool _isLikelyUrl(String text) {
    final t = text.trim();
    final hasScheme = t.startsWith(RegExp(r'(?i)https?://'));
    final looksDomain =
        RegExp(r'(?i)^([a-z0-9-]+\.)+[a-z]{2,}(/.*)?$').hasMatch(t);
    final startsWithWww = t.startsWith(RegExp(r'(?i)^www\.'));
    return hasScheme || looksDomain || startsWithWww;
  }

  String _normalizeUrl(String text) {
    final t = text.trim();
    if (t.startsWith(RegExp(r'(?i)https?://'))) return t;
    if (t.startsWith(RegExp(r'(?i)^www\.'))) return 'https://$t';
    if (RegExp(r'(?i)^([a-z0-9-]+\.)+[a-z]{2,}(/.*)?$').hasMatch(t)) {
      return 'https://$t';
    }
    return t;
  }

  Future<void> _openUrl(String raw) async {
    final uri = Uri.tryParse(_normalizeUrl(raw));
    if (uri == null) return;
    // No paramos la cámara aquí (solo abrimos si el usuario pulsa).
    await launchUrl(uri, mode: LaunchMode.platformDefault);
  }

  // ---------- Modal con enlace si es URL ----------
  Future<void> _showResultDialog(String code) async {
    if (!mounted) return;
    setState(() => _showingDialog = true);

    final isUrl = _isLikelyUrl(code);
    final display = isUrl ? _normalizeUrl(code) : code;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        title: const Text('Código QR detectado'),
        content: isUrl
            ? InkWell(
                onTap: () => _openUrl(code),
                child: Text(
                  display,
                  style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              )
            : SelectableText(code),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );

    if (mounted) {
      setState(() => _showingDialog = false);
    }
  }

  // ---------- onDetect fiable ----------
  void _handleDetect(BarcodeCapture capture) {
    // Si ya hay un modal abierto, no hagas nada hasta que se cierre
    if (_showingDialog) return;

    final codes = capture.barcodes;
    final String? code = codes.isNotEmpty ? codes.first.rawValue : null;

    if (code == null || code.isEmpty) return;

    // Mostramos SIEMPRE el modal (sea URL o no). Si es URL, habrá un enlace.
    _showResultDialog(code);
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
        title: const Text('Lector QR'),
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
      body: Stack(
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
                      border: Border.all(color: Colors.greenAccent, width: 3),
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
                                theme.colorScheme.secondary.withOpacity(0.9),
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
    );
  }
}
