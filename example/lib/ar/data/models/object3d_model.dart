import '../../domain/entities/object3d.dart';

class Object3dModel extends Object3d {
  const Object3dModel({
    required super.id,
    required super.name,
    required super.pathPicture,
    required super.pathModule3d,
    required super.pathModule3dIos,
  });

  factory Object3dModel.fromJson(Map<String, dynamic> json) {
    return Object3dModel(
      id: json['id'] as int,
      name: json['name'] as String,
      pathPicture: json['pathPicture'] as String,
      pathModule3d: json['pathModule3d'] as String,
      pathModule3dIos: json['pathModule3dIos'] as String,
    );
  }
}
