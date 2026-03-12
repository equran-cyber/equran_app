import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class BaseDB {
  final String boxName;

  // Constructor
  BaseDB(this.boxName);

  Box? _box;
  static final Map<String, Future<Box<dynamic>>> _openingBoxes =
      <String, Future<Box<dynamic>>>{};

  Future<void> initBox() async {
    if (_box != null) return;

    if (Hive.isBoxOpen(boxName)) {
      _box = Hive.box(boxName);
      return;
    }

    final Future<Box<dynamic>> openingFuture =
        _openingBoxes.putIfAbsent(boxName, () => Hive.openBox(boxName));

    try {
      _box = await openingFuture;
    } finally {
      _openingBoxes.remove(boxName);
    }
  }

  dynamic get(dynamic key, {dynamic defaultValue}) {
    return _requireBox().get(key, defaultValue: defaultValue);
  }

  bool contains(dynamic key) {
    return _requireBox().containsKey(key);
  }

  Future<void> put(dynamic key, dynamic value) async {
    await _requireBox().put(key, value);
  }

  Future<void> delete(dynamic key) async {
    await _requireBox().delete(key);
  }

  int get length => _requireBox().length;

  Box get box => _requireBox();

  Iterable<dynamic> getKeys() {
    return _requireBox().keys;
  }

  Future<void> clear() async {
    await _requireBox().clear();
  }

  ValueListenable<Box<dynamic>> get listener => _requireBox().listenable();

  Box _requireBox() {
    final box = _box;
    if (box == null) {
      throw StateError('Box "$boxName" is not initialized. Call initBox() first.');
    }
    return box;
  }
}
