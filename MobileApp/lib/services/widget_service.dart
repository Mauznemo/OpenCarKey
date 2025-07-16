@pragma('vm:entry-point')
class WidgetService {
  @pragma('vm:entry-point')
  static void backgroundCallback(Uri? uri) {
    print('Background callback received: ${uri?.host}');
  }
}
