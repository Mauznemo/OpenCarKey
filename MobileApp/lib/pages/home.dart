import 'package:flutter/material.dart';
import 'package:native_shared_preferences/native_shared_preferences.dart';
import 'package:open_car_key_app/services/ble_event_listener.dart';
import 'package:open_car_key_app/services/ble_service.dart';
import 'package:open_car_key_app/services/vehicle.dart';
import 'package:permission_handler/permission_handler.dart';

import '../components/add_vehicle_bottom_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<NativeSharedPreferences> _prefs =
      NativeSharedPreferences.getInstance();

  List<VehicleEntry> _vehicleEntries = [];

  late String _event = "--";

  Future<void> _requestPermission() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.notification,
    ].request();
  }

  void _getVehicles() async {
    var vehicles = await VehicleStorage.getVehicles();
    _vehicleEntries = vehicles
        .map((vehicle) => VehicleEntry(
            vehicleData: vehicle, isConnected: false, doorsLocked: false))
        .toList();
    setState(() {});
  }

  void _getConnectedDevices() async {
    var connectedDevices = await BleService.getConnectedDevices();

    for (var macAddress in connectedDevices) {
      _vehicleEntries
          .firstWhere((element) =>
              element.vehicleData.macAddress.toLowerCase() ==
              macAddress.toLowerCase())
          .isConnected = true;
    }

    BleService.postEvent("SEND_MESSAGE:ds\n");

    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _getVehicles();
    _getConnectedDevices();

    BleEventListener.listenForBleEvents((event) {});

    BleEventListener.onDeviceConnected = (macAddress) {
      _event = "Connected to $macAddress";
      _vehicleEntries
          .firstWhere((element) =>
              element.vehicleData.macAddress.toLowerCase() ==
              macAddress.toLowerCase())
          .isConnected = true;
      setState(() {});
    };

    BleEventListener.onDeviceDisconnected = (macAddress) {
      _event = "Disconnected from $macAddress";
      _vehicleEntries
          .firstWhere((element) =>
              element.vehicleData.macAddress.toLowerCase() ==
              macAddress.toLowerCase())
          .isConnected = false;
      setState(() {});
    };

    BleEventListener.onMessageReceived = (macAddress, message) {
      if (message.startsWith("ld")) {
        _vehicleEntries
            .firstWhere((element) =>
                element.vehicleData.macAddress.toLowerCase() ==
                macAddress.toLowerCase())
            .doorsLocked = true;
        setState(() {});
      } else if (message.startsWith("ud")) {
        _vehicleEntries
            .firstWhere((element) =>
                element.vehicleData.macAddress.toLowerCase() ==
                macAddress.toLowerCase())
            .doorsLocked = false;
        setState(() {});
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ListView.builder(
            shrinkWrap: true,
            itemCount: _vehicleEntries.length,
            itemBuilder: (context, index) {
              VehicleEntry vehicleEntry = _vehicleEntries[index];
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0)),
                  tileColor: Theme.of(context).colorScheme.secondaryContainer,
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            vehicleEntry.isConnected
                                ? Icons.bluetooth_audio
                                : Icons.bluetooth_disabled_rounded,
                            color: vehicleEntry.isConnected
                                ? Colors.green
                                : Colors.red,
                          ),
                          SizedBox(width: 10),
                          Text(vehicleEntry.vehicleData.name,
                              style: const TextStyle(fontSize: 20)),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                        child: Text(
                            "Mac Address: ${vehicleEntry.vehicleData.macAddress}, Association ID: ${vehicleEntry.vehicleData.associationId}",
                            style: const TextStyle(fontSize: 10)),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(vehicleEntry.doorsLocked
                                ? Icons.lock_outline
                                : Icons.lock_open_outlined),
                            onPressed: vehicleEntry.isConnected
                                ? () {
                                    setState(() {
                                      BleService.postEvent(
                                          vehicleEntry.doorsLocked
                                              ? "SEND_MESSAGE:ud\n"
                                              : "SEND_MESSAGE:ld\n");
                                    });
                                  }
                                : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.directions_car),
                            onPressed: vehicleEntry.isConnected
                                ? () {
                                    BleService.postEvent("SEND_MESSAGE:ut\n");
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () async {
                      // Delete vehicle from Hive box
                      VehicleStorage.removeVehicle(
                          vehicleEntry.vehicleData.macAddress);

                      print(
                          "Removing Association ID: ${vehicleEntry.vehicleData.associationId}");
                      await BleService.disassociateBle(
                          vehicleEntry.vehicleData.associationId,
                          vehicleEntry.vehicleData.macAddress);

                      _getVehicles();
                      setState(() {});
                    },
                  ),
                ),
              );
            }),
        Text(_event),
        FilledButton(
            onPressed: () async {
              await _requestPermission();
              await AddVehicleBottomSheet.showBottomSheet(context);
              //BleService.associateBle();
              /*final NativeSharedPreferences prefs = await _prefs;
              await prefs.reload();
              _event =
                  prefs.getString('device_mac_address') ?? 'Not associated';
              setState(() {});*/
              _getVehicles();
            },
            child: const Text("Add a Vehicle")),
      ],
    ));
  }
}

class VehicleEntry {
  Vehicle vehicleData;
  bool isConnected;
  bool doorsLocked;

  VehicleEntry({
    required this.vehicleData,
    required this.isConnected,
    required this.doorsLocked,
  });
}
