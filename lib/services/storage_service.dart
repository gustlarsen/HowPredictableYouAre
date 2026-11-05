import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  int getInt(String tag, int defaultValue) {
    final prefs = _prefs;
    if (prefs == null) return defaultValue;
    final raw = prefs.get(tag);
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw) ?? defaultValue;
    if (raw is double) return raw.toInt();
    return defaultValue;
  }

  Future<void> storeInt(String tag, int value) async {
    await init();
    await _prefs!.setInt(tag, value);
  }

  double getDouble(String tag, double defaultValue) {
    final prefs = _prefs;
    if (prefs == null) return defaultValue;
    final raw = prefs.get(tag);
    if (raw is double) return raw;
    if (raw is int) return raw.toDouble();
    if (raw is String) return double.tryParse(raw) ?? defaultValue;
    return defaultValue;
  }

  Future<void> storeDouble(String tag, double value) async {
    await init();
    await _prefs!.setDouble(tag, value);
  }

  String getString(String tag, String defaultValue) {
    final prefs = _prefs;
    if (prefs == null) return defaultValue;
    final raw = prefs.get(tag);
    if (raw == null) return defaultValue;
    return raw.toString();
  }

  Future<void> storeString(String tag, String value) async {
    await init();
    await _prefs!.setString(tag, value);
  }

  List<List<int>> getMarkovMatrix() {
    final prefs = _prefs;
    if (prefs == null) {
      return [
        [0, 0, 0],
        [0, 0, 0],
        [0, 0, 0],
      ];
    }
    final raw = prefs.getString('MarkovTransitionMatrix');
    if (raw == null || raw.isEmpty) {
      return [
        [0, 0, 0],
        [0, 0, 0],
        [0, 0, 0],
      ];
    }
    try {
      final decoded = json.decode(raw) as List<dynamic>;
      if (decoded.length == 3) {
        return decoded
            .map((row) => (row as List<dynamic>)
                .map((cell) => int.tryParse(cell.toString()) ?? 0)
                .toList())
            .toList();
      }
    } catch (_) {}
    return [
      [0, 0, 0],
      [0, 0, 0],
      [0, 0, 0],
    ];
  }

  Future<void> storeMarkovMatrix(List<List<int>> matrix) async {
    await init();
    await _prefs!.setString('MarkovTransitionMatrix', json.encode(matrix));
  }
}

