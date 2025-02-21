import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:open_car_key_app/services/ble_service.dart';

class ScanDialog extends StatefulWidget {
  const ScanDialog({Key? key}) : super(key: key);

  @override
  State<ScanDialog> createState() => _ScanDialogState();
}

class _ScanDialogState extends State<ScanDialog> {
  final List<Map<String, dynamic>> devices = [
    
  ];

  @override
  void initState() {
    super.initState();

    var subscription = FlutterBluePlus.onScanResults.listen(
      (results) {
        if (results.isNotEmpty) {
          ScanResult r = results.last; // the most recently found device
          print(
              '${r.device.remoteId}: "${r.advertisementData.advName}" found!');
          devices.add({
            'id': r.device.remoteId,
            'name': r.advertisementData.advName,
            'rssi': r.rssi,
          });
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
          children: [
            const Text(
              'Scanning for Bluetooth devices',
              style: TextStyle(fontSize:18),
            ),
            const SizedBox(height: 16),
            if (devices.isEmpty)
              const Center(child: CircularProgressIndicator())
            else
              Expanded(
                child: ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(devices[index]['name']),
                      subtitle: Text(devices[index]['id']),
                      trailing: Text('${devices[index]['rssi']} dBm'),
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
