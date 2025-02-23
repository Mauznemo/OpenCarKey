import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../components/add_vehicle_bottom_sheet.dart';
import '../components/edit_vehicle_bottom_sheet.dart';
import '../services/ble_service.dart';
import '../services/vehicle_service.dart';
import '../types/vehicle.dart';
import '../utils/utils.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Vehicle> vehicles = [];

  late String eventData = "--";

  final List<String> notAuthenticatedDevices = [];

  Future<void> _requestPermission() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.notification,
    ].request();
  }

  void getVehicles() async {
    final vehiclesData = await VehicleStorage.getVehicles();

    setState(() {
      vehicles = vehiclesData
          .map((vehicle) => Vehicle(
                device: BluetoothDevice.fromId(vehicle.macAddress),
                data: vehicle,
              ))
          .toList();
    });

    connectDevices();

    // getConnectedDevices();
  }

  void connectDevices() async {
    for (final vehicle in vehicles) {
      await vehicle.device.connect(autoConnect: true);
    }
  }

  void getConnectedDevices() async {
    final connectedDevices = await BleService.getConnectedDevices();

    for (final vehicle in vehicles) {
      final connectedDevice = connectedDevices.firstWhere(
        (device) => device.remoteId == vehicle.device.remoteId,
        orElse: () => vehicle.device,
      );

      vehicle.device = connectedDevice;
      vehicle.device.connect();
    }

    if (connectedDevices.isNotEmpty)
      await BleService.sendMessage(connectedDevices.first, "ds");

    setState(() {});
  }

  void processMessage(String macAddress, String message) {
    if (message.startsWith("NOT_AUTH") || message.startsWith("AUTH_FAIL")) {
      if (notAuthenticatedDevices.contains(macAddress)) {
        return;
      }
      notAuthenticatedDevices.add(macAddress);
      showDialog(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text("Not Authenticated"),
                content: Text(
                    "The device $macAddress you are trying to communicate with is not authenticated. Please make sure the pin is correct."),
                actions: [
                  TextButton(
                      onPressed: Navigator.of(context).pop,
                      child: const Text("OK"))
                ],
              ));
    } else if (message.startsWith("AUTH_OK")) {
      if (notAuthenticatedDevices.contains(macAddress)) {
        notAuthenticatedDevices.remove(macAddress);
      }
    } else if (message.startsWith("ld")) {
      setState(() => vehicles
          .firstWhere((element) =>
              element.data.macAddress.toLowerCase() == macAddress.toLowerCase())
          .doorsLocked = true);
    } else if (message.startsWith("ud")) {
      setState(() => vehicles
          .firstWhere((element) =>
              element.data.macAddress.toLowerCase() == macAddress.toLowerCase())
          .doorsLocked = false);
    } else if (message.startsWith("ut")) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text("Trunk unlocked"),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    getVehicles();

    FlutterBluePlus.events.onConnectionStateChanged.listen((event) async {
      Vehicle changedVehicle = vehicles.firstWhere(
          (vehicle) => vehicle.device.remoteId == event.device.remoteId);

      changedVehicle.device = event.device;

      if (event.connectionState == BluetoothConnectionState.connected)
        await BleService.sendMessage(
            changedVehicle.device, "AUTH:${changedVehicle.data.pin}");

      setState(() =>
          vehicles.firstWhere(
              (vehicle) => vehicle.device.remoteId == event.device.remoteId) ==
          changedVehicle);
    });

    FlutterBluePlus.events.onCharacteristicReceived.listen((event) {
      eventData = "Characteristic received: ${utf8.decode(event.value)}";
      print("Characteristic received: ${utf8.decode(event.value)}");

      processMessage(
          event.device.remoteId.toString(), utf8.decode(event.value));

      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Open Car Key"),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                getVehicles();
                setState(() {});
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            // await _requestPermission();
            await AddVehicleBottomSheet.showBottomSheet(context);
            //BleService.associateBle();
            /*final NativeSharedPreferences prefs = await _prefs;
              await prefs.reload();
              _event =
                  prefs.getString('device_mac_address') ?? 'Not associated';
              setState(() {});*/
            getVehicles();
          },
          child: const Icon(Icons.add),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ListView.builder(
                shrinkWrap: true,
                itemCount: vehicles.length,
                itemBuilder: (context, index) {
                  Vehicle vehicle = vehicles[index];
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Builder(builder: (context) {
                      //Builder needed or else colorScheme.secondaryContainer will be the fallback color
                      return ListTile(
                        onLongPress: () async {
                          await EditVehicleBottomSheet.showBottomSheet(
                              context, vehicle);
                          getVehicles();
                          setState(() {});
                        },
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0)),
                        tileColor:
                            Theme.of(context).colorScheme.secondaryContainer,
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  vehicle.device.isConnected
                                      ? Icons.bluetooth_audio
                                      : Icons.bluetooth_disabled_rounded,
                                  color: vehicle.device.isConnected
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  vehicle.data.name,
                                  style: const TextStyle(fontSize: 20),
                                ),
                                Spacer(),
                                if (notAuthenticatedDevices.contains(
                                    vehicle.device.remoteId.toString()))
                                  Icon(
                                    Icons.pin,
                                    color: Colors.amber,
                                  ),
                              ],
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 8.0, bottom: 4.0),
                              child: Text(
                                  "Mac Address: ${vehicle.data.macAddress}, Association ID: ${null}",
                                  style: const TextStyle(fontSize: 10)),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(vehicle.doorsLocked
                                      ? Icons.lock_outline
                                      : Icons.lock_open_outlined),
                                  onPressed: vehicle.device.isConnected
                                      ? () async {
                                          await BleService.sendMessage(
                                            vehicle.device,
                                            vehicle.doorsLocked ? "ud" : "ld",
                                          );
                                        }
                                      : null,
                                ),
                                vehicle.data.hasTrunkUnlock
                                    ? IconButton(
                                        icon: const Icon(Icons.directions_car),
                                        onPressed: vehicle.device.isConnected
                                            ? () async {
                                                await BleService.sendMessage(
                                                  vehicle.device,
                                                  "ut",
                                                );
                                              }
                                            : null,
                                      )
                                    : Container(),
                                vehicle.data.hasEngineStart
                                    ? IconButton(
                                        icon: const Icon(Icons.restart_alt),
                                        onPressed: vehicle.device.isConnected
                                            ? () {
                                                BleService.postEvent(
                                                    "SEND_MESSAGE:st\n");
                                              }
                                            : null,
                                      )
                                    : Container(),
                              ],
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            final confirmed = showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text("Delete Vehicle"),
                                content: Text(
                                    "Are you sure you want to delete ${vehicle.data.name}?"),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text("Cancel"),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: const Text("Delete"),
                                  ),
                                ],
                              ),
                            );
                            if (!(await confirmed)) return;

                            VehicleStorage.removeVehicle(
                                vehicle.data.macAddress);

                            setState(() => vehicles.removeAt(index));

                            if (vehicle.device.isConnected)
                              await BleService.disconnectDevice(vehicle.device);

                            // print(
                            //     "Removing Association ID: ${vehicleEntry.vehicleData.associationId}");
                            // await BleService.disassociateBle(
                            //     vehicleEntry.vehicleData.associationId,
                            //     vehicleEntry.vehicleData.macAddress);

                            getVehicles();
                          },
                        ),
                      );
                    }),
                  );
                }),
            Text(eventData),
          ],
        ));
  }
}
