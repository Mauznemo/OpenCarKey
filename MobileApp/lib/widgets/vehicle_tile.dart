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

class VehicleTile extends ConsumerStatefulWidget {
  final Vehicle vehicle;
  final int index;
  const VehicleTile({super.key, required this.vehicle, required this.index});

  @override
  ConsumerState<VehicleTile> createState() => _VehicleTileState();
}

class _VehicleTileState extends ConsumerState<VehicleTile> {
  bool _doorsCommandSending = false;
  bool _trunkCommandSending = false;
  bool _engineCommandSending = false;
  bool _windowsCommandSending = false;

  Widget _buildLoadingSpinner() {
    return SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 3,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehiclesState = ref.watch(vehiclesProvider);
    final settingsState = ref.watch(settingsProvider);
    File? imageFile = widget.vehicle.data.imagePath.isEmpty
        ? null
        : ImageUtils.loadSavedImage(widget.vehicle.data.imagePath);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        borderRadius: BorderRadius.circular(25),
        color: Theme.of(context).colorScheme.secondaryContainer,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (imageFile != null)
              Positioned.fill(
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, Colors.transparent],
                    stops: [0.1, 0.9],
                  ).createShader(bounds),
                  blendMode: BlendMode.dstIn,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
                    child: Image.file(
                      imageFile,
                      fit: BoxFit.cover,
                      color: Colors.black.withOpacity(0.4),
                      colorBlendMode: BlendMode.darken,
                    ),
                  ),
                ),
              ),
            InkWell(
              borderRadius: BorderRadius.circular(25),
              enableFeedback: false,
              onLongPress: () async {
                HapticFeedback.lightImpact();
                VehicleOptionsActionSheet.show(
                  context,
                  ref,
                  widget.vehicle,
                  widget.index,
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!settingsState.showMacAddress)
                      const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          widget.vehicle.device.isConnected
                              ? Icons.bluetooth_audio
                              : Icons.bluetooth_disabled_rounded,
                          color: widget.vehicle.device.isConnected
                              ? Colors.green
                              : Colors.red,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          widget.vehicle.data.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(width: 10),
                        if (widget.vehicle.data.noProximityKey)
                          const Icon(Icons.location_disabled),
                        const SizedBox(width: 10),
                        if (vehiclesState.unauthenticatedVehicles.contains(
                          widget.vehicle.device.macAddress.toString(),
                        ))
                          Tooltip(
                            message: 'Authentication failed',
                            triggerMode: TooltipTriggerMode.tap,
                            showDuration: const Duration(seconds: 2),
                            child: const Icon(Icons.pin, color: Colors.amber),
                          ),
                        if (vehiclesState.outdatedVehicles.contains(
                          widget.vehicle.device.macAddress.toString(),
                        ))
                          Tooltip(
                            triggerMode: TooltipTriggerMode.tap,
                            showDuration: const Duration(seconds: 5),
                            message:
                                'ESP32 firmware version mismatch. Please update your ESP32.',
                            child: const Icon(
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
                        child: Text(
                          'Mac Address: ${widget.vehicle.data.macAddress}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    if (!settingsState.showMacAddress)
                      const SizedBox(height: 10),
                    const SizedBox(height: 10),
                    Wrap(
                      runSpacing: 8,
                      children: [
                        _ActionButton(
                          icon: _doorsCommandSending
                              ? _buildLoadingSpinner()
                              : Icon(
                                  widget.vehicle.doorsLocked
                                      ? Icons.lock
                                      : Icons.lock_open,
                                  size: 30,
                                ),
                          onPressed: widget.vehicle.device.isConnected
                              ? () async {
                                  if (_doorsCommandSending) return;

                                  setState(() {
                                    _doorsCommandSending = true;
                                  });

                                  await BleBackgroundService.sendCommand(
                                    widget.vehicle.device,
                                    widget.vehicle.doorsLocked
                                        ? ClientCommand.UNLOCK_DOORS
                                        : ClientCommand.LOCK_DOORS,
                                  );

                                  setState(() {
                                    _doorsCommandSending = false;
                                  });
                                }
                              : null,
                        ),
                        if (widget.vehicle.data.features.contains(
                          Feature.trunkOpen,
                        ))
                          _ActionButton(
                            icon: _trunkCommandSending
                                ? _buildLoadingSpinner()
                                : const Icon(
                                    Icons.directions_car_outlined,
                                    size: 30,
                                  ),
                            onPressed: widget.vehicle.device.isConnected
                                ? () async {
                                    if (_trunkCommandSending) return;

                                    setState(() {
                                      _trunkCommandSending = true;
                                    });

                                    await BleBackgroundService.sendCommand(
                                      widget.vehicle.device,
                                      ClientCommand.OPEN_TRUNK,
                                    );

                                    setState(() {
                                      _trunkCommandSending = false;
                                    });
                                  }
                                : null,
                          ),
                        if (widget.vehicle.data.features.contains(
                          Feature.engine,
                        ))
                          _ActionButton(
                            icon: _engineCommandSending
                                ? _buildLoadingSpinner()
                                : Icon(
                                    widget.vehicle.engineOn
                                        ? Icons.do_disturb_alt_outlined
                                        : Icons.power_settings_new,
                                    size: 30,
                                  ),
                            onPressed: widget.vehicle.device.isConnected
                                ? () async {
                                    if (_engineCommandSending) return;

                                    setState(() {
                                      _engineCommandSending = true;
                                    });

                                    await BleBackgroundService.sendCommand(
                                      widget.vehicle.device,
                                      widget.vehicle.engineOn
                                          ? ClientCommand.STOP_ENGINE
                                          : ClientCommand.START_ENGINE,
                                    );

                                    setState(() {
                                      _engineCommandSending = false;
                                    });
                                  }
                                : null,
                          ),
                        if (widget.vehicle.data.features.contains(
                          Feature.windows,
                        ))
                          _ActionButton(
                            icon: _windowsCommandSending
                                ? _buildLoadingSpinner()
                                : Icon(
                                    widget.vehicle.windowsOpen
                                        ? Icons.keyboard_double_arrow_up
                                        : Icons.keyboard_double_arrow_down,
                                    size: 30,
                                  ),
                            onPressed: widget.vehicle.device.isConnected
                                ? () async {
                                    if (_windowsCommandSending) return;

                                    setState(() {
                                      _windowsCommandSending = true;
                                    });

                                    await BleBackgroundService.sendCommand(
                                      widget.vehicle.device,
                                      widget.vehicle.windowsOpen
                                          ? ClientCommand.CLOSE_WINDOWS
                                          : ClientCommand.OPEN_WINDOWS,
                                    );

                                    setState(() {
                                      _windowsCommandSending = false;
                                    });
                                  }
                                : null,
                          ),
                      ],
                    ),
                    if (!settingsState.showMacAddress)
                      const SizedBox(height: 5),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.onPressed});

  final Widget icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Material(
        color: Theme.of(context).colorScheme.primary.withAlpha(50),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          icon: SizedBox(width: 30, height: 30, child: Center(child: icon)),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
