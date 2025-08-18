import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  final List<String> keys = [
    'ClientID', 'CampaignName', 'Campaign_Type','USER_ID',
    'LoginHourID', 'UserMode', 'user_login_id','SIP_ID','skillstr','UserModeIndex','ManualCallerID','RecordID'
  ];

  Future<void> syncLocalStorage(InAppWebViewController? controller) async {
    if (controller == null) return;
    final prefs = await SharedPreferences.getInstance();

    for (var key in keys) {
      final value = await controller.evaluateJavascript(source: 'localStorage.getItem("$key");');
      if (value != null && value is String && value.isNotEmpty) {
        await prefs.setString(key, value);
      }
    }
  }
}
