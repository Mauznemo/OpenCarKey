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
import '../utils/image_utils.dart';

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
  bool ignoreProtocolMismatch = false;

  final List<String> notAuthenticatedDevices = [];
  final List<String> verMismatchDevices = [];

  void loadPrefs() async {
    prefs = await SharedPreferences.getInstance();

    proximityKey = prefs.getBool('proximityKey') ?? false;
    ignoreProtocolMismatch = prefs.getBool('ignoreProtocolMismatch') ?? false;

    setState(() {});
  }

  void getVehicles() async {
    final vehiclesData = await VehicleStorage.getVehicles();

    List<Vehicle> newVehicles = [];
    for (final vehicleData in vehiclesData) {
      newVehicles.add(Vehicle(
        device: BleDevice(macAddress: vehicleData.macAddress),
        data: vehicleData,
        imageFile: await ImageUtils.loadSavedImage(vehicleData.imagePath),
      ));
    }
    setState(() {
      vehicles = newVehicles;
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
    if (message.startsWith('VER')) {
      final deviceProtocolVersion = message.substring(4);

      if (deviceProtocolVersion == BleBackgroundService.PROTOCLOL_VERSION) {
        return;
      }

      if (verMismatchDevices.contains(macAddress)) {
        return;
      }
      verMismatchDevices.add(macAddress);

      if (ignoreProtocolMismatch) {
        setState(() {});
        return;
      }

      final vehicleName = vehicles
          .firstWhere((element) => element.data.macAddress == macAddress)
          .data
          .name;

      showDialog(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Protocol Version Mismatch'),
                content: Text(
                    '$vehicleName is on protocol version $deviceProtocolVersion and the app is on ${BleBackgroundService.PROTOCLOL_VERSION}. Everything you need might still work, but if not please update your ESP32 to the newest version.'),
                actions: [
                  TextButton(
                      onPressed: Navigator.of(context).pop,
                      child: const Text('Okay')),
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        prefs.setBool('ignoreProtocolMismatch', true);
                      },
                      child: const Text("Don't show this again")),
                ],
              ));
      setState(() {});
    } else if (message.startsWith('NOT_AUTH') ||
        message.startsWith('AUTH_FAIL') ||
        message.startsWith('AUTH_COOLD')) {
      if (notAuthenticatedDevices.contains(macAddress)) {
        return;
      }
      notAuthenticatedDevices.add(macAddress);
      showDialog(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Not Authenticated'),
                content: Text(message.startsWith('AUTH_COOLD')
                    ? 'The device $macAddress you are trying to communicate with is not authenticated. Please make sure the pin is correct.'
                    : 'Too many wrong authentication attempts on $macAddress. Please try again later.'),
                actions: [
                  TextButton(
                      onPressed: Navigator.of(context).pop,
                      child: const Text('Okay'))
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
            ImageUtils.deleteUnusedImages();
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
                            if (vehicle.imageFile != null)
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
                                          image: FileImage(vehicle.imageFile!),
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
                                ImageUtils.deleteUnusedImages();
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
                                      SizedBox(width: 10),
                                      if (notAuthenticatedDevices.contains(
                                          vehicle.device.macAddress.toString()))
                                        Tooltip(
                                          message: 'Device not authenticated.',
                                          triggerMode: TooltipTriggerMode.tap,
                                          showDuration: Duration(seconds: 2),
                                          child: Icon(
                                            Icons.pin,
                                            color: Colors.amber,
                                          ),
                                        ),
                                      if (verMismatchDevices.contains(
                                          vehicle.device.macAddress.toString()))
                                        Tooltip(
                                          triggerMode: TooltipTriggerMode.tap,
                                          showDuration: Duration(seconds: 5),
                                          message:
                                              'ESP32 firmware version mismatch. Please update your ESP32.',
                                          child: Icon(
                                            Icons.update_disabled,
                                            color: Colors.amber,
                                          ),
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
                                                                'OPEN_TRUNK',
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
