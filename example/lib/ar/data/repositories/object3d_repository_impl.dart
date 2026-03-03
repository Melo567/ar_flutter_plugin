import '../../domain/repositories/object3d_repository.dart';
import '../datasources/object3d_remote_datasource.dart';

class Object3dRepositoryImpl implements Object3dRepository {
  final Object3dRemoteDataSource _remoteDataSource;

  const Object3dRepositoryImpl({
    required Object3dRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  Future<Object3dListResult> getObject3dList({required int page}) async {
    final response = await _remoteDataSource.getObject3dList(page: page);
    return Object3dListResult(
      objects: response.data,
      hasMore: response.currentPage < response.lastPage,
      currentPage: response.currentPage,
    );
  }
}
