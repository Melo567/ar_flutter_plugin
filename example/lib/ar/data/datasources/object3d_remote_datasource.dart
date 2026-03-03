import 'package:dio/dio.dart';

import '../models/object3d_list_response_model.dart';

abstract class Object3dRemoteDataSource {
  Future<Object3dListResponseModel> getObject3dList({required int page});
}

class Object3dRemoteDataSourceImpl implements Object3dRemoteDataSource {
  final Dio _dio;

  static const _path = '/neighborhoods/object-3d-list';

  const Object3dRemoteDataSourceImpl({required Dio dio}) : _dio = dio;

  @override
  Future<Object3dListResponseModel> getObject3dList({required int page}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      _path,
      queryParameters: {'page': page},
    );

    if (response.data == null) {
      throw Exception('Empty response from server');
    }

    return Object3dListResponseModel.fromJson(response.data!);
  }
}
