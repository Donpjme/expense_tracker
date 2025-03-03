import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../services/receipt_scanner_service.dart';

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isInitializing = true;
  bool _isProcessing = false;
  File? _imageFile;
  final ReceiptScannerService _scannerService = ReceiptScannerService();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // Request camera permission
    final status = await Permission.camera.request();

    if (status.isGranted) {
      try {
        _cameras = await availableCameras();

        if (_cameras.isNotEmpty) {
          _cameraController = CameraController(
            _cameras[0],
            ResolutionPreset.high,
            enableAudio: false,
          );

          await _cameraController!.initialize();

          if (mounted) {
            setState(() {
              _isInitializing = false;
            });
          }
        } else {
          _showErrorMessage('No cameras available on this device');
        }
      } catch (e) {
        _showErrorMessage('Failed to initialize camera: $e');
      }
    } else {
      _showErrorMessage('Camera permission denied');
    }
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _showErrorMessage('Camera not initialized');
      return;
    }

    if (_cameraController!.value.isTakingPicture) {
      return;
    }

    try {
      final XFile photo = await _cameraController!.takePicture();

      // Convert XFile to File
      final File imageFile = File(photo.path);

      await _processCapturedImage(imageFile);
    } catch (e) {
      _showErrorMessage('Error taking picture: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final imageFile = File(pickedFile.path);
      await _processCapturedImage(imageFile);
    }
  }

  Future<void> _processCapturedImage(File imageFile) async {
    // Crop the image
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      aspectRatio: const CropAspectRatio(
          ratioX: 3, ratioY: 2), // Example aspect ratio (3:2)
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Receipt',
          toolbarColor: Theme.of(context).primaryColor,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'Crop Receipt',
        ),
      ],
    );

    if (croppedFile == null) return;

    setState(() {
      _imageFile = File(croppedFile.path);
      _isProcessing = true;
    });

    try {
      // Process the receipt image
      final Map<String, dynamic> receiptData =
          await _scannerService.scanReceipt(_imageFile!);

      // Go back to the previous screen with the extracted data
      if (mounted) {
        Navigator.of(context).pop(receiptData);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        _showErrorMessage('Failed to process receipt: $e');
      }
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_cameraController != null)
            Center(
              child: CameraPreview(_cameraController!),
            ),

          // Overlay to guide receipt placement
          const Positioned.fill(
            child: CustomPaint(
              painter: ReceiptOverlayPainter(),
            ),
          ),

          // Instructions
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.black.withAlpha(128),
              child: const Text(
                'Position the receipt within the frame',
                style: TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Loading indicator when processing
          if (_isProcessing)
            Container(
              color: Colors.black.withAlpha(178),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Analyzing receipt...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.black,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: const Icon(Icons.photo_library,
                    color: Colors.white, size: 32),
                onPressed: _isProcessing ? null : _pickImageFromGallery,
              ),
              FloatingActionButton(
                backgroundColor: Colors.white,
                onPressed: _isProcessing ? null : _takePicture,
                child: const Icon(Icons.camera_alt, color: Colors.black),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed:
                    _isProcessing ? null : () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReceiptOverlayPainter extends CustomPainter {
  const ReceiptOverlayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color =
          Colors.white.withAlpha(76) // Using withAlpha instead of withOpacity
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final double receiptWidth = size.width * 0.8;
    final double receiptHeight = size.height * 0.6;
    final double left = (size.width - receiptWidth) / 2;
    final double top = (size.height - receiptHeight) / 2;

    final Rect receiptRect = Rect.fromLTWH(
      left,
      top,
      receiptWidth,
      receiptHeight,
    );

    // Draw receipt outline
    canvas.drawRect(receiptRect, paint);

    // Draw cutout (make the area outside the receipt darker)
    final Paint backgroundPaint = Paint()
      ..color =
          Colors.black.withAlpha(128) // Using withAlpha instead of withOpacity
      ..style = PaintingStyle.fill;

    final Path path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(receiptRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, backgroundPaint);

    // Draw corner guides
    final double cornerSize = 20;
    final Paint cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Top-left corner
    canvas.drawLine(
      Offset(left, top + cornerSize),
      Offset(left, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left + cornerSize, top),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(left + receiptWidth - cornerSize, top),
      Offset(left + receiptWidth, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + receiptWidth, top),
      Offset(left + receiptWidth, top + cornerSize),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(left, top + receiptHeight - cornerSize),
      Offset(left, top + receiptHeight),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, top + receiptHeight),
      Offset(left + cornerSize, top + receiptHeight),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(left + receiptWidth - cornerSize, top + receiptHeight),
      Offset(left + receiptWidth, top + receiptHeight),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + receiptWidth, top + receiptHeight),
      Offset(left + receiptWidth, top + receiptHeight - cornerSize),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
