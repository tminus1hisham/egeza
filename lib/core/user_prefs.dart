import 'package:shared_preferences/shared_preferences.dart';

class UserPrefs {
  static const _keyName = 'user_name';
  static const _keyPhone = 'user_phone';
  static const _keyToken = 'auth_token';

  /// The account's backend role (`USER`, `TENANT`, `PATNER`, `MANAGER`, …).
  /// Kept on disk because the tab bar is built from it at launch, long before
  /// `/users/me` answers — without it an owner opens the app as a driver and
  /// only becomes an owner once the dashboard load lands.
  static const _keyRole = 'user_role';

  static const _keyTheme = 'app_theme_mode';

  /// Debug-only override of the driver/manager view mode. Absent means "follow
  /// whatever role the account actually has", which is why this is a nullable
  /// bool rather than one defaulting to false.
  static const _keyDebugManagerMode = 'debug_manager_mode';

  /// Debug-only: whether the manager view shows generated figures.
  static const _keyDebugSampleData = 'debug_sample_data';

  static Future<void> save({required String name, required String phone}) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_keyName, name),
      prefs.setString(_keyPhone, phone),
    ]);
  }

  static Future<
      ({
        String? name,
        String? phone,
        String? token,
        String? role,
        String? theme,
        bool? debugManagerMode,
        bool? debugSampleData,
      })> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      name: prefs.getString(_keyName),
      phone: prefs.getString(_keyPhone),
      token: prefs.getString(_keyToken),
      role: prefs.getString(_keyRole),
      theme: prefs.getString(_keyTheme),
      debugManagerMode: prefs.getBool(_keyDebugManagerMode),
      debugSampleData: prefs.getBool(_keyDebugSampleData),
    );
  }

  static Future<void> saveDebugSampleData(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDebugSampleData, enabled);
  }

  /// Pass null to drop the override and go back to following the account role.
  static Future<void> saveDebugManagerMode(bool? enabled) async {
    final prefs = await SharedPreferences.getInstance();
    if (enabled == null) {
      await prefs.remove(_keyDebugManagerMode);
      return;
    }
    await prefs.setBool(_keyDebugManagerMode, enabled);
  }

  static Future<void> saveTheme(String themeName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTheme, themeName);
  }

  static Future<void> saveRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRole, role);
  }

  static Future<void> clearRole() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRole);
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
