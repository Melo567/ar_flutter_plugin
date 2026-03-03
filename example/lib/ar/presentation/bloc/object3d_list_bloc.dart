import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_object3d_list_usecase.dart';
import 'object3d_list_event.dart';
import 'object3d_list_state.dart';

class Object3dListBloc extends Bloc<Object3dListEvent, Object3dListState> {
  final GetObject3dListUseCase _getObject3dList;

  Object3dListBloc({required GetObject3dListUseCase getObject3dListUseCase})
      : _getObject3dList = getObject3dListUseCase,
        super(const Object3dListInitial()) {
    on<FetchObject3dList>(_onFetch);
    on<FetchMoreObject3dList>(_onFetchMore);
  }

  Future<void> _onFetch(
    FetchObject3dList event,
    Emitter<Object3dListState> emit,
  ) async {
    emit(const Object3dListLoading());
    try {
      final result = await _getObject3dList(page: 1);
      emit(Object3dListLoaded(
        objects: result.objects,
        hasMore: result.hasMore,
        currentPage: result.currentPage,
      ));
    } catch (e) {
      emit(Object3dListError(message: e.toString()));
    }
  }

  Future<void> _onFetchMore(
    FetchMoreObject3dList event,
    Emitter<Object3dListState> emit,
  ) async {
    final current = state;
    if (current is! Object3dListLoaded || !current.hasMore) return;

    emit(Object3dListLoadingMore(objects: current.objects));
    try {
      final result = await _getObject3dList(page: current.currentPage + 1);
      emit(Object3dListLoaded(
        objects: [...current.objects, ...result.objects],
        hasMore: result.hasMore,
        currentPage: result.currentPage,
      ));
    } catch (_) {
      // Restore previous loaded state on pagination error
      emit(Object3dListLoaded(
        objects: current.objects,
        hasMore: current.hasMore,
        currentPage: current.currentPage,
      ));
    }
  }
}
