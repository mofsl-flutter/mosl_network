import 'dart:convert';
import 'dart:typed_data';
import 'package:mosl_network/shared_preference/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class Preference {
  final SharedPreferences preferences;
  final String key;

  Preference(this.preferences, this.key);

  bool get isSet => preferences.containsKey(key);

  bool get isNotSet => !isSet;

  Future<void> delete() async {
    await preferences.remove(key);
  }
}

class MapPreference extends Preference {
  MapPreference(super.preferences, super.key);

  Map<String, dynamic>? get() {
    final value = preferences.getString(key);
    if (value != null) {
      return json.decode(value);
    }
    return null;
  }

  Map<String, dynamic> getOrDefault({Map<String, dynamic>? def}) {
    return get() ?? def ?? {};
  }

  Future<void> set(Map<String, dynamic> value) async {
    await preferences.setString(key, json.encode(value));
  }
}

class StringPreference extends Preference {
  StringPreference(String key) : super(SharedPreferencesProvider.instance, key);

  String? get() {
    return preferences.getString(key);
  }

  String getOrDefault({String def = ''}) {
    return get() ?? def;
  }

  Future<void> set(String value) async {
    await preferences.setString(key, value);
  }
}

class SecureStringPreference extends StringPreference {
  SecureStringPreference(super.key);

  @override
  String? get() {
    if (isSet) {
      return super.get();
    }
    return null;
  }

  @override
  Future<void> set(String value) async {
    await super.set(value);
  }
}

class StringListPreference extends Preference {
  StringListPreference(super.preferences, super.key);

  List<String>? get() {
    return preferences.getStringList(key);
  }

  List<String> getOrDefault({List<String>? def}) {
    return get() ?? def ?? [];
  }

  Future<void> set(List<String> value) async {
    await preferences.setStringList(key, value);
  }
}

class IntPreference extends Preference {
  IntPreference(String key)
      : super(SharedPreferencesProvider.instance, key);

  int? get() {
    return preferences.getInt(key);
  }

  int getOrDefault({int def = 0}) {
    return get() ?? def;
  }

  Future<void> set(int value) async {
    await preferences.setInt(key, value);
  }
}

class BooleanPreference extends Preference {
  BooleanPreference(String key)
      : super(SharedPreferencesProvider.instance, key);

  bool? get() {
    return preferences.getBool(key);
  }

  bool getOrDefault({bool def = false}) {
    return get() ?? def;
  }

  Future<void> set(bool value) async {
    await preferences.setBool(key, value);
  }
}

abstract class BinaryPreference extends Preference {
  BinaryPreference(super.preferences, super.key);

  Uint8List? getBinary() {
    final base64Data = preferences.getString(key);
    if (base64Data != null) {
      return base64.decode(base64Data);
    }
    return null;
  }

  Future<void> setBinary(Uint8List input) async {
    await preferences.setString(key, base64.encode(input));
  }
}