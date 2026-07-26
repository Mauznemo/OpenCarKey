import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/add_vehicle_bottom_sheet.dart';
import '../providers/settings_provider.dart';
import '../providers/vehicles_provider.dart';
import '../services/settings_service.dart';
import '../services/vehicle_service.dart';
import '../models/vehicle.dart';
import '../utils/image_utils.dart';
import '../widgets/vehicle_tile.dart';
import 'activity_log_page.dart';
import 'settings.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      VehicleService.instance.init(context, ref);
      SettingsService.instance.init(context, ref);
    });
  }

  @override
  void dispose() {
    VehicleService.instance.dispose();
    SettingsService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vehiclesState = ref.watch(vehiclesProvider);
    final settingsState = ref.watch(settingsProvider);

    final orderedVehicles = vehiclesState.orderedVehicles;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Open Car Key'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return const ActivityLogPage();
                  },
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return const SettingsPage();
                  },
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await AddVehicleBottomSheet.showBottomSheet(context);
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
                  value: settingsState.proximityKey,
                  onChanged: (value) {
                    SettingsService.instance.setProximityKey(value);
                  },
                ),
                SizedBox(width: 10),
                const Text('Proximity Key', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
          Spacer(),
          ListView.builder(
            shrinkWrap: true,
            itemCount: orderedVehicles.length,
            itemBuilder: (context, index) {
              Vehicle vehicle = orderedVehicles[index];
              return VehicleTile(vehicle: vehicle, index: index);
            },
          ),
          Spacer(),
        ],
      ),
    );
  }
}
