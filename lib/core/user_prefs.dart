import 'package:shared_preferences/shared_preferences.dart';

class UserPrefs {
  static const _keyName = 'user_name';
  static const _keyPhone = 'user_phone';
  static const _keyToken = 'auth_token';

  static const _keyTheme = 'app_theme_mode';

  static Future<void> save({required String name, required String phone}) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_keyName, name),
      prefs.setString(_keyPhone, phone),
    ]);
  }

  static Future<({String? name, String? phone, String? token, String? theme})> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      name: prefs.getString(_keyName),
      phone: prefs.getString(_keyPhone),
      token: prefs.getString(_keyToken),
      theme: prefs.getString(_keyTheme),
    );
  }

  static Future<void> saveTheme(String themeName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTheme, themeName);
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
  }
}
