import 'dart:convert';
import 'package:flutter/services.dart';

class LocalizationService {
  static const List<String> supportedLanguages = ['en', 'de', 'pt', 'es'];

  String _currentLanguage = 'en';
  Map<String, dynamic> _strings = {};

  String get currentLanguage => _currentLanguage;

  Future<void> load() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/stringsHowPredict.json');
      _strings = json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      _strings = {};
    }
  }

  void setLanguage(String lang) {
    if (supportedLanguages.contains(lang)) {
      _currentLanguage = lang;
    }
  }

  /// Retrieves localized string by key (e.g. 'string1', 'string34')
  String t(String key, {String fallback = ''}) {
    final cleanKey = key.startsWith('_') ? key.substring(1) : key;
    final localizedKey = '${_currentLanguage}_$cleanKey';
    if (_strings.containsKey(localizedKey)) {
      final val = _strings[localizedKey].toString();
      // Remove HTML line breaks if present
      return val.replaceAll('<br>', '\n');
    }

    // Fallback to English
    final enKey = 'en_$cleanKey';
    if (_strings.containsKey(enKey)) {
      final val = _strings[enKey].toString();
      return val.replaceAll('<br>', '\n');
    }

    return fallback.isNotEmpty ? fallback : key;
  }
}
