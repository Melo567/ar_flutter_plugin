import 'package:equatable/equatable.dart';

abstract class Object3dListEvent extends Equatable {
  const Object3dListEvent();

  @override
  List<Object?> get props => [];
}

class FetchObject3dList extends Object3dListEvent {
  const FetchObject3dList();
}

class FetchMoreObject3dList extends Object3dListEvent {
  const FetchMoreObject3dList();
}
