import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _unityChannel = MethodChannel('com.kisekae.unity/channel');

Future<void> launchUnity(BuildContext context) async {
  try {
    await _unityChannel.invokeMethod<void>('openUnity');
  } on PlatformException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open Unity: ${e.message}')),
      );
    }
  }
}

class UnityScreen extends StatelessWidget {
  const UnityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('3D Try-On')),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.view_in_ar),
          label: const Text('Open 3D View'),
          onPressed: () => launchUnity(context),
        ),
      ),
    );
  }
}
