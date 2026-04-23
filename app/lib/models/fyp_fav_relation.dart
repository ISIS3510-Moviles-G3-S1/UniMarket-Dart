import 'package:hive/hive.dart';

part 'fyp_fav_relation.g.dart';

@HiveType(typeId: 1)
class FypFavRelation extends HiveObject {
  @HiveField(0)
  final String favId;

  @HiveField(1)
  final String fypItemId;

  FypFavRelation({required this.favId, required this.fypItemId});
}
