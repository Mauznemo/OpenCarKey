import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/edit_vehicle_bottom_sheet.dart';
import '../models/vehicle.dart';
import '../providers/vehicles_provider.dart';
import '../services/vehicle_service.dart';
import '../utils/image_utils.dart';

class VehicleOptionsActionSheet {
  static void show(
    BuildContext context,
    WidgetRef ref,
    Vehicle vehicle,
    int index,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      barrierColor: Theme.of(
        context,
      ).colorScheme.onSurface.withValues(alpha: 0.3),
      builder: (BuildContext context) {
        final vehiclesState = ref.watch(vehiclesProvider);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 10),
                ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('Edit'),
                  onTap: () async {
                    Navigator.pop(context);
                    await EditVehicleBottomSheet.showBottomSheet(
                        context, vehicle);
                    ImageUtils.deleteUnusedImages();
                  },
                ),
                if (index > 0)
                  ListTile(
                    leading: Icon(Icons.keyboard_arrow_up),
                    title: Text('Move Up'),
                    onTap: () {
                      VehicleService.instance.moveVehicleUp(vehicle, index);
                      Navigator.pop(context);
                    },
                  ),
                if (index < vehiclesState.vehicles.length - 1)
                  ListTile(
                    leading: Icon(Icons.keyboard_arrow_down),
                    title: Text('Move Down'),
                    onTap: () {
                      VehicleService.instance.moveVehicleDown(vehicle, index);
                      Navigator.pop(context);
                    },
                  ),
                ListTile(
                  leading: Icon(Icons.delete_forever),
                  title: Text('Delete'),
                  onTap: () => _deleteVehicle(context, vehicle),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void _deleteVehicle(BuildContext context, Vehicle vehicle) async {
    Navigator.pop(context);

    final confirmed = showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vehicle'),
        content: Text('Are you sure you want to delete ${vehicle.data.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!(await confirmed)) return;
    print('Deleting vehicle: ${vehicle.data.name}');

    VehicleService.instance.removeVehicle(vehicle.data.macAddress);
  }
}
