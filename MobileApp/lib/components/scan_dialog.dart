import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../services/ble_service.dart';

class ScanDialog extends StatefulWidget {
  const ScanDialog({super.key});

  @override
  State<ScanDialog> createState() => _ScanDialogState();
}

class _ScanDialogState extends State<ScanDialog> {
  final List<Map<String, dynamic>> devices = [];

  @override
  void initState() {
    super.initState();

    var subscription = FlutterBluePlus.onScanResults.listen(
      (results) {
        if (results.isNotEmpty) {
          ScanResult r = results.last;
          print(
              '${r.device.remoteId}: "${r.advertisementData.advName}" found!');
          devices.add({
            'id': r.device.remoteId.toString(),
            'name': r.advertisementData.advName == ''
                ? 'Unknown'
                : r.advertisementData.advName,
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
                            final device = await BleService.connectToDevice(
                                devices[index]['device']);

                            if (device != null) {
                              Navigator.of(context).pop(device);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to connect to device'),
                                ),
                              );
                            }
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
