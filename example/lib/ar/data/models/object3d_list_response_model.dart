import 'object3d_model.dart';

class Object3dListResponseModel {
  final List<Object3dModel> data;
  final int currentPage;
  final int lastPage;
  final int total;

  const Object3dListResponseModel({
    required this.data,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  factory Object3dListResponseModel.fromJson(Map<String, dynamic> json) {
    final rawList = json['data'] as List<dynamic>? ?? [];
    return Object3dListResponseModel(
      data: rawList
          .map((e) => Object3dModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      currentPage: json['current_page'] as int,
      lastPage: json['last_page'] as int,
      total: json['total'] as int,
    );
  }
}
