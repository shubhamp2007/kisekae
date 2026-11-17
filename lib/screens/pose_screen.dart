import 'package:flutter/material.dart';
import 'package:flutter_unity_widget_2/flutter_unity_widget_2.dart';
import 'package:permission_handler/permission_handler.dart';

const _unityTarget = 'AvatarRoot';
const _unitySetGarment = 'SetGarment';
const _unityClearGarment = 'ClearGarment';
const _unitySwitchCamera = 'SwitchCamera';
const _slot = 'outfit';

const _accent = Color(0xFF8E2F40);
const _background = Color(0xFFF8F4F2);

class Outfit {
  const Outfit(this.id, {this.imageAsset});

  final String id;
  final String? imageAsset;
}

const _outfits = <Outfit>[
  Outfit('Casual_Suit_1', imageAsset: 'assets/images/ar/Casual_Suit_1.png'),
  Outfit('Casual_Suit_2', imageAsset: 'assets/images/ar/Casual_Suit_2.png'),
  Outfit('Casual_Suit_3', imageAsset: 'assets/images/ar/Casual_Suit_3.png'),
  Outfit('Casual_Suit_4', imageAsset: 'assets/images/ar/Casual_Suit_4.png'),
];

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
  String? _selected = _outfits.first.id;

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

  void _selectOutfit(Outfit outfit) {
    if (_selected == outfit.id) {
      setState(() => _selected = null);
      _unity?.postMessage(_unityTarget, _unityClearGarment, _slot);
      return;
    }
    setState(() => _selected = outfit.id);
    _unity?.postMessage(_unityTarget, _unitySetGarment, '$_slot:${outfit.id}');
  }

  void _switchCamera() {
    _unity?.postMessage(_unityTarget, _unitySwitchCamera, '');
  }

  void _saveLook() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saving looks is not set up yet.')),
    );
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

  Widget _thumbnail(Outfit outfit) {
    final selected = _selected == outfit.id;
    final borderWidth = selected ? 3.0 : 1.2;
    const outerRadius = 12.0;
    return GestureDetector(
      onTap: () => _selectOutfit(outfit),
      child: Container(
        width: 52,
        height: 64,
        padding: const EdgeInsets.all(2),
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(outerRadius),
          border: Border.all(
            color: selected ? _accent : Colors.black87,
            width: borderWidth,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(outerRadius - borderWidth),
          child: outfit.imageAsset != null
              ? Image.asset(
                  outfit.imageAsset!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                )
              : const Icon(Icons.checkroom, color: Colors.black54),
        ),
      ),
    );
  }

  Widget _roundButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.92),
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        icon: Icon(icon, color: _accent),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  Widget _liveView() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            if (!_checked)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
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
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            if (_granted)
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [for (final o in _outfits) _thumbnail(o)],
                  ),
                ),
              ),
            if (_granted)
              Positioned(
                right: 10,
                bottom: 10,
                child: _roundButton(
                  icon: Icons.flip_camera_android,
                  onPressed: _switchCamera,
                  tooltip: 'Switch camera',
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 18),
          ),
        ),
        centerTitle: true,
        title: const Text(
          "Ar TryOn",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _liveView(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  onPressed: _saveLook,
                  child: const Text(
                    'Save Look',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
