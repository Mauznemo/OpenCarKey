import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  SharedPreferences? _storage;
  final Map<String, Object> _cache = {};

  Future<void> initialize() async {
    _storage = await SharedPreferences.getInstance();
  }

  T? read<T extends Object>(
      String key, {
        T? defaultValue,
        bool ignoreCache = false,
      }) {
    if (_cache.containsKey(key) && !ignoreCache) return _cache[key] as T;
    final value = switch (T) {
      const (String) => _storage?.getString(key) as T?,
      const (int) => _storage?.getInt(key) as T?,
      const (double) => _storage?.getDouble(key) as T?,
      const (bool) => _storage?.getBool(key) as T?,
      const (List<String>) => _storage?.getStringList(key) as T?,
      _ => throw UnsupportedError('Type $T is not supported'),
    };
    if (value != null) _cache[key] = value;
    return value ?? defaultValue;
  }

  Future<bool> write<T extends Object>(String key, T value) async {
    final success = await switch (T) {
      const (String) => _storage!.setString(key, value as String),
      const (int) => _storage!.setInt(key, value as int),
      const (double) => _storage!.setDouble(key, value as double),
      const (bool) => _storage!.setBool(key, value as bool),
      const (List<String>) =>
          _storage!.setStringList(key, value as List<String>),
      _ => throw UnsupportedError('Type $T is not supported'),
    };
    if (!success) return false;
    _cache[key] = value;
    return true;
  }

  bool exists(String key) {
    final value = _storage?.containsKey(key);
    return value ?? false;
  }

  Future<bool> delete(String key) async {
    final success = await _storage!.remove(key);
    if (!success) return false;
    _cache.remove(key);
    return true;
  }

  Future<void> clear() {
    _cache.clear();
    return _storage!.clear();
  }
}