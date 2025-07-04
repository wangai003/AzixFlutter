import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

typedef OnScan = void Function(String code);

class QrScannerWidget extends StatelessWidget {
  final OnScan onScan;
  final GlobalKey qrKey;

  const QrScannerWidget({Key? key, required this.onScan, required this.qrKey}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return QRView(
      key: qrKey,
      onQRViewCreated: (controller) {
        controller.scannedDataStream.listen((scanData) {
          if (scanData.code != null) {
            onScan(scanData.code!);
            controller.dispose();
            Navigator.of(context).pop();
          }
        });
      },
      overlay: QrScannerOverlayShape(
        borderColor: Colors.amber,
        borderRadius: 12,
        borderLength: 30,
        borderWidth: 10,
        cutOutSize: 250,
      ),
    );
  }
} 