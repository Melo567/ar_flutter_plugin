import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/object3d.dart';
import '../bloc/object3d_list_bloc.dart';
import '../bloc/object3d_list_event.dart';
import '../bloc/object3d_list_state.dart';
import 'object3d_list_item_widget.dart';

class Object3dListPanel extends StatefulWidget {
  final Object3d? selectedObject;
  final ValueChanged<Object3d> onObjectSelected;

  const Object3dListPanel({
    Key? key,
    required this.selectedObject,
    required this.onObjectSelected,
  }) : super(key: key);

  @override
  State<Object3dListPanel> createState() => _Object3dListPanelState();
}

class _Object3dListPanelState extends State<Object3dListPanel> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 150) {
      context.read<Object3dListBloc>().add(const FetchMoreObject3dList());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BlocBuilder<Object3dListBloc, Object3dListState>(
        builder: (context, state) {
          if (state is Object3dListLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is Object3dListError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(height: 4),
                  Text(
                    'Erreur de chargement',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  TextButton(
                    onPressed: () => context
                        .read<Object3dListBloc>()
                        .add(const FetchObject3dList()),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          final List<Object3d> objects;
          if (state is Object3dListLoaded) {
            objects = state.objects;
          } else if (state is Object3dListLoadingMore) {
            objects = state.objects;
          } else {
            objects = const [];
          }

          final isLoadingMore = state is Object3dListLoadingMore;

          return ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: objects.length + (isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == objects.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              final object = objects[index];
              return Object3dListItemWidget(
                object: object,
                isSelected: widget.selectedObject?.id == object.id,
                onTap: () => widget.onObjectSelected(object),
              );
            },
          );
        },
      ),
    );
  }
}
