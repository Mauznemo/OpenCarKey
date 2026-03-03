import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../services/ble_background_service.dart';
import '../services/ble_service.dart';

class ScanDialog extends StatefulWidget {
  const ScanDialog({super.key});

  @override
  State<ScanDialog> createState() => _ScanDialogState();
}

class _ScanDialogState extends State<ScanDialog> {
  final List<Map<String, dynamic>> devices = [];

  ({bool isOckDevice, String decodedName}) _decodeBluetoothName(
      String encoded) {
    const int key = 0x5A;

    // Convert HEX back to bytes
    List<int> bytes = [];

    for (int i = 0; i < encoded.length; i += 2) {
      String hexByte = encoded.substring(i, i + 2);
      int value = int.parse(hexByte, radix: 16);
      bytes.add(value ^ key);
    }

    String decoded = String.fromCharCodes(bytes);

    if (decoded.startsWith("OCK_")) {
      return (isOckDevice: true, decodedName: decoded.substring(4));
    }

    return (isOckDevice: false, decodedName: '');
  }

  @override
  void initState() {
    super.initState();

    var subscription = FlutterBluePlus.onScanResults.listen(
      (results) {
        if (results.isNotEmpty) {
          ScanResult r = results.last;
          final nameResult = _decodeBluetoothName(r.advertisementData.advName);
          if (!nameResult.isOckDevice) {
            return;
          }
          debugPrint(
              '${r.device.remoteId}: "${nameResult.decodedName}" found!');
          devices.add({
            'id': r.device.remoteId.toString(),
            'name': nameResult.decodedName,
            'rssi': r.rssi,
            'device': r.device,
          });
          setState(() {});
        }
      },
      onError: (e) => print(e),
    );
    FlutterBluePlus.cancelWhenScanComplete(subscription);
    BleService.scanForDevices();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scanning for Bluetooth devices',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: devices.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(devices[index]['name']),
                          subtitle: Text(devices[index]['id']),
                          trailing: Text('${devices[index]['rssi']} dBm'),
                          onTap: () async {
                            final device =
                                await BleBackgroundService.connectToDevice(
                                    devices[index]['device']);

                            if (!context.mounted) return;

                            Navigator.of(context).pop(device);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    BleService.stopScan();
    super.dispose();
  }
}
