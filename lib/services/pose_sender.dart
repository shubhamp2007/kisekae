import 'dart:convert';
import 'dart:ui' show Size;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

const _keyTypes = <PoseLandmarkType>[
  PoseLandmarkType.leftShoulder,
  PoseLandmarkType.rightShoulder,
  PoseLandmarkType.leftElbow,
  PoseLandmarkType.rightElbow,
  PoseLandmarkType.leftWrist,
  PoseLandmarkType.rightWrist,
  PoseLandmarkType.leftHip,
  PoseLandmarkType.rightHip,
  PoseLandmarkType.leftKnee,
  PoseLandmarkType.rightKnee,
  PoseLandmarkType.leftAnkle,
  PoseLandmarkType.rightAnkle,
];

class PoseSender {
  PoseSender(this.send, {this.minIntervalMs = 40, this.sendDepth = false});

  final void Function(String json) send;
  final int minIntervalMs;
  final bool sendDepth;

  int _lastSentMs = 0;

  static double _r(double v) => double.parse(v.toStringAsFixed(3));

  void onPose(Pose pose, Size imageSize) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSentMs < minIntervalMs) return;
    _lastSentMs = now;

    final flat = <double>[];
    for (final t in _keyTypes) {
      final lm = pose.landmarks[t];
      if (lm == null) {
        flat.addAll(const [0, 0, 0, 0]);
        continue;
      }
      flat.addAll([
        _r(lm.x / imageSize.width),
        _r(lm.y / imageSize.height),
        sendDepth ? _r(lm.z / imageSize.width) : 0,
        _r(lm.likelihood),
      ]);
    }
    send(jsonEncode({'l': flat}));
  }
}
