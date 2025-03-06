import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../components/add_vehicle_bottom_sheet.dart';
import '../components/edit_vehicle_bottom_sheet.dart';
import '../services/ble_background_service.dart';
import '../services/vehicle_service.dart';
import '../types/ble_device.dart';
import '../types/vehicle.dart';
import '../utils/utils.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FlutterBackgroundService service = FlutterBackgroundService();
  List<Vehicle> vehicles = [];

  late String eventData = '--';

  final List<String> notAuthenticatedDevices = [];

  void getVehicles() async {
    final vehiclesData = await VehicleStorage.getVehicles();

    setState(() {
      vehicles = vehiclesData
          .map((vehicle) => Vehicle(
                device: BleDevice(macAddress: vehicle.macAddress),
                data: vehicle,
              ))
          .toList();
    });

    getConnectedDevices();

    BleBackgroundService.tryConnectAll();
  }

  void getConnectedDevices() async {
    await VehicleStorage.reloadPrefs();
    final connectedDevices = await BleBackgroundService.getConnectedDevices();
    List<String> connectedDeviceMacs =
        connectedDevices.map((e) => e.macAddress).toList();

    for (final vehicle in vehicles) {
      final connectedDevice = connectedDevices.firstWhere(
        (device) => device.macAddress == vehicle.device.macAddress,
        orElse: () => vehicle.device,
      );

      vehicle.device = connectedDevice;
      vehicle.device.isConnected =
          connectedDeviceMacs.contains(vehicle.device.macAddress);
      print(
          'Checking connected device: ${vehicle.device.macAddress}: Connected: ${vehicle.device.isConnected}');
    }

    setState(() {});
  }

  void processMessage(String macAddress, String message) {
    if (message.startsWith('NOT_AUTH') || message.startsWith('AUTH_FAIL')) {
      if (notAuthenticatedDevices.contains(macAddress)) {
        return;
      }
      notAuthenticatedDevices.add(macAddress);
      showDialog(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Not Authenticated'),
                content: Text(
                    'The device $macAddress you are trying to communicate with is not authenticated. Please make sure the pin is correct.'),
                actions: [
                  TextButton(
                      onPressed: Navigator.of(context).pop,
                      child: const Text('OK'))
                ],
              ));
      setState(() {});
    } else if (message.startsWith('AUTH_OK')) {
      if (notAuthenticatedDevices.contains(macAddress)) {
        notAuthenticatedDevices.remove(macAddress);
        setState(() {});
      }
    } else if (message.startsWith('ld')) {
      setState(() => vehicles
          .firstWhere((element) =>
              element.data.macAddress.toLowerCase() == macAddress.toLowerCase())
          .doorsLocked = true);
    } else if (message.startsWith('ud')) {
      setState(() => vehicles
          .firstWhere((element) =>
              element.data.macAddress.toLowerCase() == macAddress.toLowerCase())
          .doorsLocked = false);
    } else if (message.startsWith('ut')) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Trunk unlocked'),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    service.on('message_received').listen((event) {
      if (event != null) {
        processMessage(event['macAddress'], event['message']);
      }
    });
    service.on('connection_state_changed').listen((event) {
      if (event != null) {
        getConnectedDevices();
      }
    });
    getVehicles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Open Car Key'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                //getVehicles();
                BleBackgroundService.tryConnectAll();
                getConnectedDevices();
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
                                    vehicle.device.macAddress.toString()))
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
                                  'Mac Address: ${vehicle.data.macAddress}',
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
                                      ? () {
                                          BleBackgroundService.sendMessage(
                                            vehicle.device,
                                            vehicle.doorsLocked ? 'ud' : 'ld',
                                          );
                                        }
                                      : null,
                                ),
                                vehicle.data.hasTrunkUnlock
                                    ? IconButton(
                                        icon: const Icon(Icons.directions_car),
                                        onPressed: vehicle.device.isConnected
                                            ? () {
                                                BleBackgroundService
                                                    .sendMessage(
                                                  vehicle.device,
                                                  'ut',
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
                                                //TODO: Implement engine start
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
                                title: const Text('Delete Vehicle'),
                                content: Text(
                                    'Are you sure you want to delete ${vehicle.data.name}?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (!(await confirmed)) return;
                            print('Deleting vehicle: ${vehicle.data.name}');

                            VehicleStorage.removeVehicle(
                                vehicle.data.macAddress);

                            setState(() => vehicles.removeAt(index));

                            BleBackgroundService.reloadVehicles();

                            BleBackgroundService.disconnectDevice(
                                vehicle.device);

                            //getVehicles();
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
