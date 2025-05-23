import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../components/add_vehicle_bottom_sheet.dart';
import '../components/edit_vehicle_bottom_sheet.dart';
import '../services/ble_background_service.dart';
import '../services/vehicle_service.dart';
import '../types/ble_device.dart';
import '../types/vehicle.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FlutterBackgroundService service = FlutterBackgroundService();
  List<Vehicle> vehicles = [];

  late SharedPreferences prefs;
  bool proximityKey = false;

  final List<String> notAuthenticatedDevices = [];

  void loadPrefs() async {
    prefs = await SharedPreferences.getInstance();

    proximityKey = prefs.getBool('proximityKey') ?? false;

    setState(() {});
  }

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

    BleBackgroundService.requestData();

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
    } else if (message.startsWith('LOCKED')) {
      setState(() => vehicles
          .firstWhere((element) =>
              element.data.macAddress.toLowerCase() == macAddress.toLowerCase())
          .doorsLocked = true);
    } else if (message.startsWith('UNLOCKED')) {
      setState(() => vehicles
          .firstWhere((element) =>
              element.data.macAddress.toLowerCase() == macAddress.toLowerCase())
          .doorsLocked = false);
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
    loadPrefs();
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
            IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.pushNamed(context, '/settings').then((_) {
                    loadPrefs();
                  });
                }),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            await AddVehicleBottomSheet.showBottomSheet(context);
            getVehicles();
          },
          child: const Icon(Icons.add),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Switch(
                    value: proximityKey,
                    onChanged: (value) {
                      prefs.setBool('proximityKey', value);
                      BleBackgroundService.setProximityKey(value);

                      setState(() {
                        proximityKey = value;
                      });
                    },
                  ),
                  SizedBox(width: 10),
                  const Text(
                    'Proximity Key',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
            Spacer(),
            ListView.builder(
                shrinkWrap: true,
                itemCount: vehicles.length,
                itemBuilder: (context, index) {
                  Vehicle vehicle = vehicles[index];
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Builder(builder: (context) {
                      //Builder needed or else colorScheme.secondaryContainer will be the fallback color
                      return ClipRRect(
                          borderRadius: BorderRadius.circular(20.0),
                          child: Stack(children: [
                            // Faded image background
                            Positioned.fill(
                              child: ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.white, Colors.transparent],
                                  stops: [0.1, 0.9],
                                ).createShader(bounds),
                                blendMode: BlendMode.dstIn,
                                child: ImageFiltered(
                                  imageFilter: ImageFilter.blur(
                                    sigmaX: 3.0,
                                    sigmaY: 3.0,
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      image: DecorationImage(
                                        image: AssetImage('assets/car.jpg'),
                                        fit: BoxFit.cover,
                                        colorFilter: ColorFilter.mode(
                                          Colors.black.withOpacity(
                                              0.4), // Adjust opacity to control darkness
                                          BlendMode.darken,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            ListTile(
                              onLongPress: () async {
                                await EditVehicleBottomSheet.showBottomSheet(
                                    context, vehicle);
                                getVehicles();
                                setState(() {});
                              },
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20.0)),
                              tileColor: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer,
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
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall,
                                      ),
                                      SizedBox(width: 10),
                                      if (vehicle.data.noProximityKey)
                                        Icon(
                                          Icons.location_disabled,
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
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 8.0, bottom: 4.0),
                                    child: Text(
                                        'Mac Address: ${vehicle.data.macAddress}',
                                        style: const TextStyle(fontSize: 12)),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(right: 5),
                                        child: Ink(
                                          decoration: ShapeDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withAlpha(50),
                                            shape: CircleBorder(),
                                          ),
                                          child: IconButton(
                                            icon: Icon(
                                                vehicle.doorsLocked
                                                    ? Icons.lock
                                                    : Icons.lock_open,
                                                size: 30),
                                            onPressed:
                                                vehicle.device.isConnected
                                                    ? () {
                                                        BleBackgroundService
                                                            .sendMessage(
                                                          vehicle.device,
                                                          vehicle.doorsLocked
                                                              ? 'UNLOCK'
                                                              : 'LOCK',
                                                        );
                                                      }
                                                    : null,
                                          ),
                                        ),
                                      ),
                                      vehicle.data.hasTrunkUnlock
                                          ? Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 5),
                                              child: Ink(
                                                decoration: ShapeDecoration(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .withAlpha(50),
                                                  shape: CircleBorder(),
                                                ),
                                                child: IconButton(
                                                  icon: const Icon(
                                                    Icons
                                                        .directions_car_outlined,
                                                    size: 30,
                                                  ),
                                                  onPressed:
                                                      vehicle.device.isConnected
                                                          ? () {
                                                              BleBackgroundService
                                                                  .sendMessage(
                                                                vehicle.device,
                                                                'UNLOCK_TRUNK',
                                                              );
                                                            }
                                                          : null,
                                                ),
                                              ),
                                            )
                                          : Container(),
                                      vehicle.data.hasEngineStart
                                          ? Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 5),
                                              child: Ink(
                                                decoration: ShapeDecoration(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .withAlpha(50),
                                                  shape: CircleBorder(),
                                                ),
                                                child: IconButton(
                                                  icon: const Icon(
                                                    Icons.restart_alt,
                                                    size: 30,
                                                  ),
                                                  onPressed:
                                                      vehicle.device.isConnected
                                                          ? () {
                                                              //TODO: Implement engine start
                                                            }
                                                          : null,
                                                ),
                                              ),
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
                                  print(
                                      'Deleting vehicle: ${vehicle.data.name}');

                                  VehicleStorage.removeVehicle(
                                      vehicle.data.macAddress);

                                  setState(() => vehicles.removeAt(index));

                                  BleBackgroundService.reloadVehicles();

                                  BleBackgroundService.disconnectDevice(
                                      vehicle.device);

                                  //getVehicles();
                                },
                              ),
                            ),
                          ]));
                    }),
                  );
                }),
            Spacer(),
          ],
        ));
  }
}
