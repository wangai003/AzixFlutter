import 'package:flutter/material.dart';

typedef OnScan = void Function(String code);

class QrScannerWidget extends StatelessWidget {
  final OnScan onScan;
  final GlobalKey qrKey;

  const QrScannerWidget({Key? key, required this.onScan, required this.qrKey}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'QR scanning is not supported on web.',
        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
      ),
    );
  }
} 