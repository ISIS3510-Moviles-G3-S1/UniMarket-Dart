
import 'package:hive/hive.dart';

class FypFavRelationStorage {
  static const String _boxName = 'fyp_fav_relations';

  Future<Box<List>> _box() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<List>(_boxName);
    }
    return Hive.openBox<List>(_boxName);
  }

  Future<void> addRelation({required String favId, required String fypItemId}) async {
    final box = await _box();
    final current = box.get(favId)?.cast<String>() ?? <String>[];
    if (!current.contains(fypItemId)) {
      current.add(fypItemId);
      await box.put(favId, current);
    }
  }

  Future<List<String>> getRelationsByFavId(String favId) async {
    final box = await _box();
    return box.get(favId)?.cast<String>() ?? <String>[];
  }

  Future<void> removeRelation({required String favId, required String fypItemId}) async {
    final box = await _box();
    final current = box.get(favId)?.cast<String>() ?? <String>[];
    current.remove(fypItemId);
    await box.put(favId, current);
  }

  Future<void> clearAll() async {
    final box = await _box();
    await box.clear();
  }
}
