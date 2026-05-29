import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/app_data.dart';

class OCRScannerScreen extends StatefulWidget {
  final List<String> studentNames;
  const OCRScannerScreen({super.key, required this.studentNames});

  @override
  State<OCRScannerScreen> createState() => _OCRScannerScreenState();
}

class _OCRScannerScreenState extends State<OCRScannerScreen> {
  final TextRecognizer _textRecognizer = TextRecognizer();
  bool _isProcessing = false;
  File? _capturedImage;
  
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    AppData.preventLock = true;
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        // Find the back camera
        final backCamera = _cameras!.firstWhere(
          (cam) => cam.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras!.first,
        );
        _cameraController = CameraController(
          backCamera,
          ResolutionPreset.medium, // 'medium' is usually good enough for OCR (approx 720p or 480p)
          enableAudio: false,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint("Camera Init Error: $e");
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer.close();
    AppData.preventLock = false;
    super.dispose();
  }

  Future<void> _captureAndProcess() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final XFile imageFile = await _cameraController!.takePicture();
      
      setState(() {
         _capturedImage = File(imageFile.path);
      });
      
      // Pause camera preview (optional, helps signify capture)
      await _cameraController!.pausePreview();

      final inputImage = InputImage.fromFilePath(imageFile.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      String? matchedName;
      final fullText = recognizedText.text.toUpperCase();
      final normalizedFullText = fullText.replaceAll(RegExp(r'\s+'), ' ');

      for (String name in widget.studentNames) {
        final upperName = name.toUpperCase();
        final normalizedName = upperName.replaceAll(RegExp(r'\s+'), ' ');

        bool match = false;

        // 1. Exact match after stripping newlines/extra spaces
        if (normalizedFullText.contains(normalizedName)) {
          match = true;
        } else {
          // 2. Check if all significant words exist in the text
          final words = normalizedName.split(' ').where((w) => w.length > 2).toList();
          if (words.isNotEmpty) {
            bool allWordsFound = true;
            for (String word in words) {
              if (!fullText.contains(word)) {
                allWordsFound = false;
                break;
              }
            }
            if (allWordsFound) {
              match = true;
            } else {
              // 3. Fallback: check comma-separated surname
              final parts = upperName.split(',');
              if (parts.isNotEmpty && parts[0].trim().length > 2 && fullText.contains(parts[0].trim())) {
                match = true;
              }
            }
          }
        }

        if (match) {
          matchedName = name;
          break;
        }
      }

      if (!mounted) return;

      if (matchedName != null) {
        _showMatchDialog(matchedName);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No matching student name found on the ID.')),
        );
        // Resume preview for retry
        setState(() {
          _capturedImage = null;
        });
        await _cameraController!.resumePreview();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR Error: $e')),
        );
        setState(() {
          _capturedImage = null;
        });
        await _cameraController!.resumePreview();
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showMatchDialog(String name) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.teal, size: 28),
            SizedBox(width: 8),
            Text('Student ID Matched'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Scanned ID belongs to:', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.teal),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Restart camera for retry
              setState(() {
                _capturedImage = null;
              });
              await _cameraController?.resumePreview();
            },
            child: const Text('RETRY', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);       // Close dialog
              Navigator.pop(context, name); // Return to live attendance
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('CONFIRM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR ID SCANNER'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: double.infinity,
                height: 350, // Slightly taller for the camera preview
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: _capturedImage != null
                      ? Image.file(_capturedImage!, fit: BoxFit.cover)
                      : (_isCameraInitialized
                          ? Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: double.infinity,
                                  child: CameraPreview(_cameraController!),
                                ),
                                // Guide overlay
                                Container(
                                  width: 250,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.teal.shade400.withOpacity(0.8), width: 3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ],
                            )
                          : const Center(
                              child: CircularProgressIndicator(color: Colors.teal),
                            )),
                ),
              ),
              const SizedBox(height: 40),
              if (_isProcessing)
                const Column(
                  children: [
                    CircularProgressIndicator(color: Colors.teal),
                    SizedBox(height: 12),
                    Text('Reading ID card...', style: TextStyle(color: Colors.teal, fontSize: 13)),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: _isCameraInitialized ? _captureAndProcess : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.document_scanner_rounded, color: Colors.white),
                    label: const Text('SCAN PHYSICAL ID',
                        style: TextStyle(
                            color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              const SizedBox(height: 20),
              const Text(
                'Position the NU-D ID card inside the frame and tap scan to read the student\'s name.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
