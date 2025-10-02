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
  );

  bool _scanned = false;
  String? scannedCode;

  // Estado del flash (solo móvil)
  bool _torchOn = false;

  // Animación de la línea de escaneo
  late final AnimationController _lineController;
  late final Animation<double> _lineAnimation;

  // Tamaño del visor
  static const double _frameSize = 260;
  static const double _borderRadius = 16;

  @override
  void initState() {
    super.initState();
    _lineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _lineAnimation = CurvedAnimation(
      parent: _lineController,
      curve: Curves.easeInOut,
    );
  }

  // === Helpers URL (solo se usa en el modal) ===
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
    await launchUrl(uri, mode: LaunchMode.platformDefault);
  }

  // === Modal: SOLO muestra enlace clickable si es URL; si no, texto normal ===
  void _showAlert(String code) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        final isUrl = _isLikelyUrl(code);
        final display = isUrl ? _normalizeUrl(code) : code;

        return AlertDialog(
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
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => _scanned = false); // permitir re-escanear
              },
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
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
              setState(() => _torchOn = false); // reset del icono al cambiar
            },
          ),
          // Botón de flash (en Web queda desactivado)
          IconButton(
            tooltip: kIsWeb ? 'Flash no soportado en Web' : 'Flash',
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
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
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    final String? code =
                        barcodes.isNotEmpty ? barcodes.first.rawValue : null;

                    if (!_scanned && code != null) {
                      setState(() {
                        _scanned = true;
                        scannedCode = code;
                      });
                      // NO abrimos la URL aquí. Solo mostramos el modal (evita pantalla gris).
                      _showAlert(code);
                    }
                  },
                ),

                // Overlay oscuro con hueco transparente + esquinas
                CustomPaint(
                  painter: _ScannerOverlayPainter(
                    frameSize: _frameSize,
                    borderRadius: _borderRadius,
                    strokeColor: Colors.greenAccent,
                    strokeWidth: 4,
                    cornerLength: 28,
                  ),
                  size: Size.infinite,
                ),

                // Línea de escaneo animada
                Center(
                  child: SizedBox(
                    width: _frameSize,
                    height: _frameSize,
                    child: AnimatedBuilder(
                      animation: _lineAnimation,
                      builder: (context, child) {
                        final y = (_frameSize - 4) * _lineAnimation.value; // 4px alto línea
                        return Stack(
                          children: [
                            Positioned(
                              top: y,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 4,
                                margin: const EdgeInsets.symmetric(horizontal: 8),
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
                            ),
                          ],
                        );
                      },
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
          // Pie informativo (NO clickable; solo info)
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                scannedCode != null
                    ? 'Código detectado: $scannedCode'
                    : 'Escanea un código QR',
                textAlign: TextAlign.center,
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
    _lineController.dispose();
    super.dispose();
  }
}

/// Pintor del overlay: oscurece toda la pantalla y recorta un
/// rectángulo redondeado en el centro (visor), dibujando además
/// esquinas de guía.
class _ScannerOverlayPainter extends CustomPainter {
  _ScannerOverlayPainter({
    required this.frameSize,
    required this.borderRadius,
    required this.strokeColor,
    required this.strokeWidth,
    required this.cornerLength,
  });

  final double frameSize;
  final double borderRadius;
  final Color strokeColor;
  final double strokeWidth;
  final double cornerLength;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(
      center: center,
      width: frameSize,
      height: frameSize,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // 1) Capa para poder usar BlendMode.clear
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.55);
    canvas.saveLayer(Offset.zero & size, Paint());

    // 2) Fondo oscurecido
    canvas.drawRect(Offset.zero & size, overlayPaint);

    // 3) Hueco transparente
    overlayPaint.blendMode = BlendMode.clear;
    canvas.drawRRect(rrect, overlayPaint);

    // 4) Cerramos la capa
    canvas.restore();

    // 5) Esquinas del visor
    final cornerPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square;

    _drawCorner(canvas, cornerPaint, rrect.outerRect.topLeft, Corner.topLeft);
    _drawCorner(canvas, cornerPaint, rrect.outerRect.topRight, Corner.topRight);
    _drawCorner(
        canvas, cornerPaint, rrect.outerRect.bottomLeft, Corner.bottomLeft);
    _drawCorner(
        canvas, cornerPaint, rrect.outerRect.bottomRight, Corner.bottomRight);
  }

  void _drawCorner(Canvas canvas, Paint paint, Offset origin, Corner corner) {
    final path = Path();
    switch (corner) {
      case Corner.topLeft:
        path.moveTo(origin.dx, origin.dy + cornerLength);
        path.lineTo(origin.dx, origin.dy);
        path.lineTo(origin.dx + cornerLength, origin.dy);
        break;
      case Corner.topRight:
        path.moveTo(origin.dx - cornerLength, origin.dy);
        path.lineTo(origin.dx, origin.dy);
        path.lineTo(origin.dx, origin.dy + cornerLength);
        break;
      case Corner.bottomLeft:
        path.moveTo(origin.dx, origin.dy - cornerLength);
        path.lineTo(origin.dx, origin.dy);
        path.lineTo(origin.dx + cornerLength, origin.dy);
        break;
      case Corner.bottomRight:
        path.moveTo(origin.dx - cornerLength, origin.dy);
        path.lineTo(origin.dx, origin.dy);
        path.lineTo(origin.dx, origin.dy - cornerLength);
        break;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.frameSize != frameSize ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.strokeColor != strokeColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.cornerLength != cornerLength;
  }
}

enum Corner { topLeft, topRight, bottomLeft, bottomRight }
