import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_unity_widget_2/flutter_unity_widget_2.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:kisekae/services/pose_sender.dart';

const _unityObject = 'PoseDriver';
const _unityLandmarks = 'OnLandmarks';
const _unityMirror = 'SetMirror';
const _unityAspect = 'SetAspect';

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
  bool _starting = false;

  final _detector = PoseDetector(options: PoseDetectorOptions());
  final ValueNotifier<List<Pose>> _poses = ValueNotifier(const []);
  bool _isDetecting = false;

  UnityWidgetController? _unity;
  late final PoseSender _sender = PoseSender(
    (json) => _unity?.postMessage(_unityObject, _unityLandmarks, json),
  );
  bool _settingsSent = false;

  String? _error;
  bool _showSkeleton = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCamera();
    _detector.close();
    _poses.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _stopCamera().then((_) {
        if (mounted) setState(() {});
      });
    } else if (state == AppLifecycleState.resumed) {
      if (_cameras.isNotEmpty && _camera == null) {
        _startCamera(_cameras[_camIdx]);
      }
    }
  }

  Future<void> _init() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) setState(() => _error = 'Camera permission denied.');
      return;
    }
    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      if (mounted) setState(() => _error = 'No cameras found on this device.');
      return;
    }
    _camIdx = _cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    if (_camIdx < 0) _camIdx = 0;
    await _startCamera(_cameras[_camIdx]);
  }

  Future<void> _stopCamera() async {
    final cam = _camera;
    _camera = null;
    if (cam == null) return;
    try {
      if (cam.value.isStreamingImages) await cam.stopImageStream();
    } catch (_) {}
    try {
      await cam.dispose();
    } catch (_) {}
  }

  Future<void> _startCamera(CameraDescription description) async {
    if (_starting) return;
    _starting = true;
    try {
      await _stopCamera();

      final controller = CameraController(
        description,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      try {
        await controller.initialize();
      } catch (e) {
        if (mounted) setState(() => _error = 'Camera error: $e');
        return;
      }

      if (!mounted) {
        await controller.dispose();
        return;
      }

      _poses.value = const [];
      _settingsSent = false;
      setState(() {
        _error = null;
        _camera = controller;
      });

      await controller.startImageStream(_onFrame);
    } finally {
      _starting = false;
    }
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
      if (cam == null || !cam.value.isInitialized) return;

      final inputImage = _toInputImage(image, cam.description);
      if (inputImage == null) return;

      final poses = await _detector.processImage(inputImage);
      if (!mounted) return;
      _poses.value = poses;

      if (poses.isNotEmpty) {
        final preview = cam.value.previewSize!;
        final imageSize = Size(preview.height, preview.width);

        _syncUnitySettings(cam, imageSize);
        _sender.onPose(poses.first, imageSize);
      }
    } catch (e) {
      debugPrint('Pose frame error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  void _syncUnitySettings(CameraController cam, Size imageSize) {
    final unity = _unity;
    if (_settingsSent || unity == null) return;
    final front = cam.description.lensDirection == CameraLensDirection.front;
    unity.postMessage(_unityObject, _unityMirror, front ? 'true' : 'false');
    unity.postMessage(
      _unityObject,
      _unityAspect,
      (imageSize.width / imageSize.height).toStringAsFixed(4),
    );
    _settingsSent = true;
  }

  InputImage? _toInputImage(CameraImage image, CameraDescription description) {
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

  void _onUnityCreated(UnityWidgetController controller) {
    _unity = controller;
    _settingsSent = false;
  }

  void _onUnityMessage(dynamic message) {
    debugPrint('From Unity: $message');
  }

  @override
  Widget build(BuildContext context) {
    final cam = _camera;
    final cameraReady = cam != null && cam.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Live Try-On'),
        actions: [
          IconButton(
            icon: Icon(_showSkeleton ? Icons.visibility : Icons.visibility_off),
            tooltip: 'Show skeleton on preview',
            onPressed: () => setState(() => _showSkeleton = !_showSkeleton),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android),
            tooltip: 'Flip camera',
            onPressed: _flipCamera,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: UnityWidget(
              onUnityCreated: _onUnityCreated,
              onUnityMessage: _onUnityMessage,
              fullscreen: false,
            ),
          ),

          if (cameraReady)
            Positioned(
              top: 12,
              right: 12,
              width: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CameraPreview(
                  cam,
                  child: _showSkeleton
                      ? LayoutBuilder(
                          builder: (context, constraints) {
                            final preview = cam.value.previewSize!;
                            return ValueListenableBuilder<List<Pose>>(
                              valueListenable: _poses,
                              builder: (context, poses, _) => CustomPaint(
                                painter: _SkeletonPainter(
                                  poses: poses,
                                  imageSize: Size(
                                    preview.height,
                                    preview.width,
                                  ),
                                  isFrontCamera:
                                      cam.description.lensDirection ==
                                      CameraLensDirection.front,
                                ),
                                size: constraints.biggest,
                              ),
                            );
                          },
                        )
                      : null,
                ),
              ),
            ),

          if (_error != null)
            Positioned(
              top: 8,
              left: 12,
              right: 140,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ),

          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: ValueListenableBuilder<List<Pose>>(
                valueListenable: _poses,
                builder: (context, poses, _) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    poses.isEmpty ? 'Please face the camera' : 'Tracking',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonPainter extends CustomPainter {
  _SkeletonPainter({
    required this.poses,
    required this.imageSize,
    required this.isFrontCamera,
  });

  final List<Pose> poses;
  final Size imageSize;
  final bool isFrontCamera;

  static final _bonePaint = Paint()
    ..color = const Color(0xFF00E5FF)
    ..strokeWidth = 2
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  static final _jointPaint = Paint()
    ..color = const Color(0xFFFFEB3B)
    ..style = PaintingStyle.fill;

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
        canvas.drawCircle(_translate(lm, size), 3, _jointPaint);
      }
    }
  }

  Offset _translate(PoseLandmark lm, Size canvasSize) {
    double x = lm.x / imageSize.width * canvasSize.width;
    final y = lm.y / imageSize.height * canvasSize.height;
    if (isFrontCamera) x = canvasSize.width - x;
    return Offset(x, y);
  }

  @override
  bool shouldRepaint(_SkeletonPainter old) =>
      old.poses != poses || old.isFrontCamera != isFrontCamera;
}
