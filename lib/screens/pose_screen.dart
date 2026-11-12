import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

const _bones = <(PoseLandmarkType, PoseLandmarkType)>[
  (PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder),
  (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip),
  (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip),
  (PoseLandmarkType.leftHip, PoseLandmarkType.rightHip),
  (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow),
  (PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist),
  (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow),
  (PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist),
  (PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee),
  (PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle),
  (PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee),
  (PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle),
  (PoseLandmarkType.leftEar, PoseLandmarkType.leftEye),
  (PoseLandmarkType.leftEye, PoseLandmarkType.nose),
  (PoseLandmarkType.nose, PoseLandmarkType.rightEye),
  (PoseLandmarkType.rightEye, PoseLandmarkType.rightEar),
  (PoseLandmarkType.leftAnkle, PoseLandmarkType.leftHeel),
  (PoseLandmarkType.leftHeel, PoseLandmarkType.leftFootIndex),
  (PoseLandmarkType.rightAnkle, PoseLandmarkType.rightHeel),
  (PoseLandmarkType.rightHeel, PoseLandmarkType.rightFootIndex),
];

class PoseDetectionScreen extends StatefulWidget {
  const PoseDetectionScreen({super.key});

  @override
  State<PoseDetectionScreen> createState() => _PoseDetectionScreenState();
}

class _PoseDetectionScreenState extends State<PoseDetectionScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  List<CameraDescription> _cameras = [];
  int _camIdx = 1;

  final _detector = PoseDetector(options: PoseDetectorOptions());
  List<Pose> _poses = [];

  bool _isDetecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    _detector.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      cam.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _startCamera(_cameras[_camIdx]);
    }
  }

  Future<void> _init() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() => _error = 'Camera permission denied.');
      return;
    }
    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      setState(() => _error = 'No cameras found on this device.');
      return;
    }
    _camIdx = _cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    if (_camIdx < 0) _camIdx = 0;
    await _startCamera(_cameras[_camIdx]);
  }

  Future<void> _startCamera(CameraDescription description) async {
    final prev = _camera;
    if (prev != null) {
      await prev.stopImageStream();
      await prev.dispose();
    }

    final controller = CameraController(
      description,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    try {
      await controller.initialize();
    } catch (e) {
      setState(() => _error = 'Camera error: $e');
      return;
    }

    if (!mounted) return;
    setState(() {
      _camera = controller;
      _poses = [];
    });

    controller.startImageStream(_onFrame);
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    _camIdx = (_camIdx + 1) % _cameras.length;
    await _startCamera(_cameras[_camIdx]);
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_isDetecting) return;
    _isDetecting = true;

    try {
      final cam = _camera;
      if (cam == null) return;

      final inputImage = _toInputImage(image, cam.description);
      if (inputImage == null) return;

      final poses = await _detector.processImage(inputImage);
      if (mounted) setState(() => _poses = poses);
    } finally {
      _isDetecting = false;
    }
  }

  InputImage? _toInputImage(
    CameraImage image,
    CameraDescription description,
  ) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    final sensorOrientation = description.sensorOrientation;
    InputImageRotation? rotation;
    if (description.lensDirection == CameraLensDirection.front) {
      rotation = InputImageRotationValue.fromRawValue(
        (360 - sensorOrientation) % 360,
      );
    } else {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    }
    if (rotation == null) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Pose Detection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_android),
            tooltip: 'Flip camera',
            onPressed: _flipCamera,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            _CameraFill(controller: cam),
            CustomPaint(
              painter: _SkeletonPainter(
                poses: _poses,
                imageSize: Size(
                  cam.value.previewSize!.height,
                  cam.value.previewSize!.width,
                ),
                screenSize: constraints.biggest,
                isFrontCamera:
                    _cameras[_camIdx].lensDirection ==
                    CameraLensDirection.front,
              ),
            ),

            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _poses.isEmpty
                        ? 'Point camera at a person'
                        : '${_poses.first.landmarks.length} landmarks detected',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CameraFill extends StatelessWidget {
  const _CameraFill({required this.controller});
  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final previewRatio = controller.value.aspectRatio;
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: 100,
            height: 100 / previewRatio,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}

class _SkeletonPainter extends CustomPainter {
  _SkeletonPainter({
    required this.poses,
    required this.imageSize,
    required this.screenSize,
    required this.isFrontCamera,
  });

  final List<Pose> poses;
  final Size imageSize;
  final Size screenSize;
  final bool isFrontCamera;

  static final _bonePaint = Paint()
    ..color = const Color(0xFF00E5FF)
    ..strokeWidth = 3
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  static final _jointPaint = Paint()
    ..color = const Color(0xFFFFEB3B)
    ..style = PaintingStyle.fill;

  static final _jointBorderPaint = Paint()
    ..color = Colors.black54
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    for (final pose in poses) {
      for (final (a, b) in _bones) {
        final lmA = pose.landmarks[a];
        final lmB = pose.landmarks[b];
        if (lmA == null || lmB == null) continue;
        if (lmA.likelihood < 0.5 || lmB.likelihood < 0.5) continue;

        canvas.drawLine(
          _translate(lmA, size),
          _translate(lmB, size),
          _bonePaint,
        );
      }

      for (final lm in pose.landmarks.values) {
        if (lm.likelihood < 0.5) continue;
        final pt = _translate(lm, size);
        canvas.drawCircle(pt, 5, _jointPaint);
        canvas.drawCircle(pt, 5, _jointBorderPaint);
      }
    }
  }

  Offset _translate(PoseLandmark lm, Size canvasSize) {
    double x = lm.x / imageSize.width * canvasSize.width;
    double y = lm.y / imageSize.height * canvasSize.height;
    if (isFrontCamera) x = canvasSize.width - x;

    return Offset(x, y);
  }

  @override
  bool shouldRepaint(_SkeletonPainter old) =>
      old.poses != poses ||
      old.screenSize != screenSize ||
      old.isFrontCamera != isFrontCamera;
}

