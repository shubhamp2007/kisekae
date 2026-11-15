import 'package:flutter/material.dart';
import 'package:flutter_unity_widget_2/flutter_unity_widget_2.dart';
import 'package:permission_handler/permission_handler.dart';

class PoseDetectionScreen extends StatefulWidget {
  const PoseDetectionScreen({super.key});

  @override
  State<PoseDetectionScreen> createState() => _PoseDetectionScreenState();
}

class _PoseDetectionScreenState extends State<PoseDetectionScreen> {
  UnityWidgetController? _unity;
  bool _checked = false;
  bool _granted = false;
  bool _unityReady = false;

  @override
  void initState() {
    super.initState();
    _requestCamera();
  }

  Future<void> _requestCamera() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() {
      _granted = status.isGranted;
      _checked = true;
    });
  }

  void _onUnityCreated(UnityWidgetController controller) {
    _unity = controller;
    if (mounted) setState(() => _unityReady = true);
  }

  void _onUnityMessage(dynamic message) {
    debugPrint('From Unity: $message');
  }

  Widget _permissionView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Camera access is needed for the live try-on.',
              style: TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: openAppSettings,
              child: const Text('Open settings'),
            ),
            TextButton(
              onPressed: _requestCamera,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (!_checked)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else if (!_granted)
            _permissionView()
          else
            Positioned.fill(
              child: UnityWidget(
                onUnityCreated: _onUnityCreated,
                onUnityMessage: _onUnityMessage,
                fullscreen: false,
              ),
            ),
          if (_granted && !_unityReady)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
