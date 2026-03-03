import 'package:equatable/equatable.dart';

import '../../domain/entities/object3d.dart';

abstract class Object3dListState extends Equatable {
  const Object3dListState();

  @override
  List<Object?> get props => [];
}

class Object3dListInitial extends Object3dListState {
  const Object3dListInitial();
}

class Object3dListLoading extends Object3dListState {
  const Object3dListLoading();
}

class Object3dListLoaded extends Object3dListState {
  final List<Object3d> objects;
  final bool hasMore;
  final int currentPage;

  const Object3dListLoaded({
    required this.objects,
    required this.hasMore,
    required this.currentPage,
  });

  @override
  List<Object?> get props => [objects, hasMore, currentPage];
}

class Object3dListLoadingMore extends Object3dListState {
  final List<Object3d> objects;

  const Object3dListLoadingMore({required this.objects});

  @override
  List<Object?> get props => [objects];
}

class Object3dListError extends Object3dListState {
  final String message;

  const Object3dListError({required this.message});

  @override
  List<Object?> get props => [message];
}
