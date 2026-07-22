import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _keyCopyPageAsImage = 'copy_page_as_image_enabled';

  Future<bool> getCopyPageAsImageEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyCopyPageAsImage) ?? true;
  }

  Future<void> setCopyPageAsImageEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCopyPageAsImage, enabled);
  }
}
