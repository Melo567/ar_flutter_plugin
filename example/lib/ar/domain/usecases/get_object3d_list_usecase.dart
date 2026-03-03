import '../repositories/object3d_repository.dart';

class GetObject3dListUseCase {
  final Object3dRepository _repository;

  const GetObject3dListUseCase({required Object3dRepository repository})
      : _repository = repository;

  Future<Object3dListResult> call({required int page}) {
    return _repository.getObject3dList(page: page);
  }
}
