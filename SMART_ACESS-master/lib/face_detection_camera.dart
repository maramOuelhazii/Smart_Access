import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:async';
import 'add_user_details_screen.dart'; // New screen for adding user details
import 'dart:io';

class FaceDetectionScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const FaceDetectionScreen({super.key, required this.cameras});

  @override
  _FaceDetectionScreenState createState() => _FaceDetectionScreenState();
}

class _FaceDetectionScreenState extends State<FaceDetectionScreen> {
  late CameraController _cameraController;
  late FaceDetector _faceDetector;
  bool _isDetecting = false;
  bool _cameraFacingFront = false;
  List<Face> _faces = [];
  XFile? _capturedImage; // Store the captured image

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(options: FaceDetectorOptions(enableContours: true));
    _initializeCamera();
  }

  void _initializeCamera() {
    _cameraController = CameraController(
      widget.cameras[_cameraFacingFront ? 1 : 0],
      ResolutionPreset.medium,
    );

    _cameraController.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _startImageStream();
    });
  }

  void _startImageStream() {
    _cameraController.startImageStream((CameraImage image) async {
      if (_isDetecting) return;
      _isDetecting = true;

      final InputImage inputImage = _convertCameraImage(image);
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      setState(() {
        _faces = faces;
      });

      _isDetecting = false;
    });
  }

  InputImage _convertCameraImage(CameraImage image) {
    return InputImage.fromBytes(
      bytes: image.planes[0].bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  void _flipCamera() {
    setState(() {
      _cameraFacingFront = !_cameraFacingFront;
    });
    _initializeCamera();
  }

  Future<void> _takePicture() async {
    if (!_cameraController.value.isInitialized) return;

    try {
      final XFile picture = await _cameraController.takePicture();
      setState(() {
        _capturedImage = picture; // Save the captured image
      });

      // Navigate to the confirmation dialog
      _showConfirmationDialog(picture);
    } catch (e) {
      print("Error taking picture: $e");
    }
  }

  void _showConfirmationDialog(XFile picture) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Picture"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.file(File(picture.path), height: 200),
            const SizedBox(height: 10),
            const Text("Is this the correct picture?"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close the dialog
              final newUser = await Navigator.push<Map<String, dynamic>>(
                context,
                MaterialPageRoute(
                  builder: (context) => AddUserDetailsScreen(imagePath: picture.path),
                ),
              );

              if (newUser != null) {
                // Pass the new user data back to the parent widget (MainScreen)
                Navigator.pop(context, newUser);
              }
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraController.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        CameraPreview(_cameraController),
        _buildFaceBoundingBoxes(),
        Positioned(
          bottom: 20,
          left: MediaQuery.of(context).size.width / 2 - 60,
          child: Row(
            children: [
              FloatingActionButton(
                onPressed: _flipCamera,
                child: const Icon(Icons.flip_camera_android),
              ),
              const SizedBox(width: 20),
              FloatingActionButton(
                onPressed: _takePicture,
                child: const Icon(Icons.camera),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFaceBoundingBoxes() {
    return Stack(
      children: _faces.map((face) {
        return Positioned(
          left: face.boundingBox.left,
          top: face.boundingBox.top,
          width: face.boundingBox.width,
          height: face.boundingBox.height,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green, width: 3),
            ),
          ),
        );
      }).toList(),
    );
  }
}