import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../modals/vehicle_options_action_sheet.dart';
import '../models/vehicle.dart';
import '../providers/settings_provider.dart';
import '../providers/vehicles_provider.dart';
import '../services/ble_background_service.dart';
import '../types/ble_commands.dart';
import '../types/features.dart';
import '../utils/image_utils.dart';

class VehicleTile extends ConsumerWidget {
  final Vehicle vehicle;
  final int index;
  const VehicleTile({super.key, required this.vehicle, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesState = ref.watch(vehiclesProvider);
    final settingsState = ref.watch(settingsProvider);
    File? imageFile = vehicle.data.imagePath.isEmpty
        ? null
        : ImageUtils.loadSavedImage(vehicle.data.imagePath);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(20.0),
          child: Stack(children: [
            // Faded image background
            if (imageFile != null)
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
                          image: FileImage(imageFile),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            Colors.black.withOpacity(0.4),
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
                HapticFeedback.lightImpact();
                VehicleOptionsActionSheet.show(context, ref, vehicle, index);
              },
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0)),
              tileColor: Theme.of(context).colorScheme.secondaryContainer,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!settingsState.showMacAddress) const SizedBox(height: 3),
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
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      SizedBox(width: 10),
                      if (vehicle.data.noProximityKey)
                        Icon(
                          Icons.location_disabled,
                        ),
                      SizedBox(width: 10),
                      if (vehiclesState.unauthenticatedVehicles
                          .contains(vehicle.device.macAddress.toString()))
                        Tooltip(
                          message: 'Invalid HMAC',
                          triggerMode: TooltipTriggerMode.tap,
                          showDuration: Duration(seconds: 2),
                          child: Icon(
                            Icons.pin,
                            color: Colors.amber,
                          ),
                        ),
                      if (vehiclesState.outdatedVehicles
                          .contains(vehicle.device.macAddress.toString()))
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
                  if (settingsState.showMacAddress)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                      child: Text('Mac Address: ${vehicle.data.macAddress}',
                          style: const TextStyle(fontSize: 12)),
                    ),
                  if (!settingsState.showMacAddress) const SizedBox(height: 10),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 5),
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
                            onPressed: vehicle.device.isConnected
                                ? () {
                                    BleBackgroundService.sendCommand(
                                      vehicle.device,
                                      vehicle.doorsLocked
                                          ? ClientCommand.UNLOCK_DOORS
                                          : ClientCommand.LOCK_DOORS,
                                    );
                                  }
                                : null,
                          ),
                        ),
                      ),
                      vehicle.data.features.contains(Feature.trunkOpen)
                          ? Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 5),
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
                                    Icons.directions_car_outlined,
                                    size: 30,
                                  ),
                                  onPressed: vehicle.device.isConnected
                                      ? () {
                                          BleBackgroundService.sendCommand(
                                            vehicle.device,
                                            ClientCommand.OPEN_TRUNK,
                                          );
                                        }
                                      : null,
                                ),
                              ),
                            )
                          : Container(),
                      vehicle.data.features.contains(Feature.engine)
                          ? Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 5),
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
                                  onPressed: vehicle.device.isConnected
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
                  if (!settingsState.showMacAddress) const SizedBox(height: 5),
                ],
              ),
            ),
          ])),
    );
  }
}
