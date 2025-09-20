import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math';

Future<bool> requestPermissions() async {
  final micStatus = await Permission.microphone.request();
  final camStatus = await Permission.camera.request();
  return micStatus.isGranted && camStatus.isGranted;
}



String generateRoomId() {
  final random = Random();
  return (100000 + random.nextInt(899999)).toString(); // 6-digit code
}

void copyToClipboard(BuildContext context,String text) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('Room ID copied to clipboard'),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      duration: const Duration(seconds: 2),
    ),
  );
}
