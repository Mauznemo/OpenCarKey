import 'package:home_widget/home_widget.dart';

import 'ble_background_service.dart';

@pragma('vm:entry-point')
class WidgetService {
  static int _counter = 0;
  @pragma('vm:entry-point')
  static void backgroundCallback(Uri? uri) {
    print(
        'Background callback received: ${uri?.host} ${uri?.path} ${uri?.query}');
    if (uri != null) {
      // Parse the action type from query parameters
      final actionType = uri.queryParameters['action_type'] ?? 'unknown_action';

      print('Action type: $actionType');

      // Handle different action types
      switch (actionType) {
        case 'test':
          _counter++;
          HomeWidget.saveWidgetData('test', _counter.toString());
          break;
        default:
          print('Unknown action type: $actionType');
      }
      _updateWidget();
    }
  }

  static void _sendConnectedVehicles() async {
    var data = await BleBackgroundService.getConnectedDevices();
    HomeWidget.saveWidgetData('connectedVehicles', data.toString());
    _updateWidget();
  }

  static void _updateWidget() {
    HomeWidget.updateWidget(
      name: 'HomescreenWidgetReceiver',
    );
  }
}
