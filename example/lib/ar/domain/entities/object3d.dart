class Object3d {
  final int id;
  final String name;
  final String pathPicture;
  final String pathModule3d;
  final String pathModule3dIos;

  const Object3d({
    required this.id,
    required this.name,
    required this.pathPicture,
    required this.pathModule3d,
    required this.pathModule3dIos,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Object3d && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
