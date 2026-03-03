import '../entities/object3d.dart';

class Object3dListResult {
  final List<Object3d> objects;
  final bool hasMore;
  final int currentPage;

  const Object3dListResult({
    required this.objects,
    required this.hasMore,
    required this.currentPage,
  });
}

abstract class Object3dRepository {
  Future<Object3dListResult> getObject3dList({required int page});
}
