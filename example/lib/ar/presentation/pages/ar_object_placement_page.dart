import 'dart:io';

import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:ar_flutter_plugin/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../../data/datasources/object3d_remote_datasource.dart';
import '../../data/repositories/object3d_repository_impl.dart';
import '../../domain/entities/object3d.dart';
import '../../domain/usecases/get_object3d_list_usecase.dart';
import '../bloc/object3d_list_bloc.dart';
import '../bloc/object3d_list_event.dart';
import '../widgets/object3d_list_panel.dart';

class ArObjectPlacementPage extends StatefulWidget {
  const ArObjectPlacementPage({Key? key}) : super(key: key);

  @override
  State<ArObjectPlacementPage> createState() => _ArObjectPlacementPageState();
}

class _ArObjectPlacementPageState extends State<ArObjectPlacementPage> {
  // AR managers
  ARSessionManager? _arSessionManager;
  ARObjectManager? _arObjectManager;
  ARAnchorManager? _arAnchorManager;

  // Placed objects tracking
  final List<ARNode> _nodes = [];
  final List<ARAnchor> _anchors = [];

  // Selection & placement state
  Object3d? _selectedObject;
  String? _selectedNodeName;
  bool _isPlacingObject = false;

  // Scale gesture tracking
  double _pinchBaseScale = 0.2;

  late final Object3dListBloc _bloc;

  static const double _defaultScale = 0.2;
  static const double _minScale = 0.05;
  static const double _maxScale = 2.0;

  /// Rotation sensitivity in radians per pixel dragged on the rotation pad.
  static const double _rotationSensitivity = 0.012;

  static const String _apiBaseUrl =
      'https://gateway.my-preprod.space/api/immo/v2';

  @override
  void initState() {
    super.initState();
    _bloc = _buildBloc()..add(const FetchObject3dList());
  }

  Object3dListBloc _buildBloc() {
    final dio = Dio(BaseOptions(baseUrl: _apiBaseUrl));
    final dataSource = Object3dRemoteDataSourceImpl(dio: dio);
    final repository = Object3dRepositoryImpl(remoteDataSource: dataSource);
    return Object3dListBloc(
      getObject3dListUseCase: GetObject3dListUseCase(repository: repository),
    );
  }

  @override
  void dispose() {
    _arSessionManager?.dispose();
    _bloc.close();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  ARNode? _findNodeByName(String name) {
    return _nodes.cast<ARNode?>().firstWhere(
          (n) => n!.name == name,
          orElse: () => null,
        );
  }

  ARAnchor? _findAnchorForNode(String nodeName) {
    return _anchors.cast<ARAnchor?>().firstWhere(
          (a) => a is ARPlaneAnchor && a.childNodes.contains(nodeName),
          orElse: () => null,
        );
  }

  // ── AR callbacks ──────────────────────────────────────────────────────────

  void _onARViewCreated(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager arLocationManager,
  ) {
    _arSessionManager = arSessionManager;
    _arObjectManager = arObjectManager;
    _arAnchorManager = arAnchorManager;

    _arSessionManager!.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      showWorldOrigin: false,
      handleTaps: true,
      handlePans: true,
      handleRotation: true,
    );

    _arObjectManager!.onInitialize();

    _arSessionManager!.onPlaneOrPointTap = _onPlaneOrPointTapped;
    _arObjectManager!.onNodeTap = _onNodeTapped;
  }

  Future<void> _onPlaneOrPointTapped(
    List<ARHitTestResult> hitTestResults,
  ) async {
    if (_selectedObject == null) return;

    final hit = hitTestResults.cast<ARHitTestResult?>().firstWhere(
          (r) => r!.type == ARHitTestResultType.plane,
          orElse: () => null,
        );
    if (hit == null) return;

    setState(() => _isPlacingObject = true);

    try {
      final anchor = ARPlaneAnchor(transformation: hit.worldTransform);
      final didAddAnchor = await _arAnchorManager!.addAnchor(anchor) ?? false;

      if (!didAddAnchor) {
        _showError('Impossible de créer un ancrage sur cette surface.');
        return;
      }

      _anchors.add(anchor);

      //final uri = Platform.isIOS
      //    ? _selectedObject!.pathModule3dIos
      //    : _selectedObject!.pathModule3d;

      final uri = _selectedObject!.pathModule3d;

      final node = ARNode(
        type: NodeType.webGLB,
        uri: uri,
        scale: vm.Vector3.all(_defaultScale),
        position: vm.Vector3.zero(),
        rotation: vm.Vector4(1.0, 0.0, 0.0, 0.0),
        data: {'objectId': _selectedObject!.id, 'name': _selectedObject!.name},
      );

      final didAddNode =
          await _arObjectManager!.addNode(node, planeAnchor: anchor) ?? false;

      if (didAddNode) {
        _nodes.add(node);
        setState(() => _selectedNodeName = node.name);
      } else {
        _arAnchorManager!.removeAnchor(anchor);
        _anchors.remove(anchor);
        _showError('Impossible de placer l\'objet sur cette surface.');
      }
    } finally {
      if (mounted) setState(() => _isPlacingObject = false);
    }
  }

  void _onNodeTapped(List<String> nodeNames) {
    if (nodeNames.isEmpty) return;
    final tapped = _findNodeByName(nodeNames.first);
    if (tapped == null) return;
    setState(() {
      _selectedNodeName = tapped.name;
      _pinchBaseScale = tapped.scale.x;
    });
  }

  // ── Scale gesture (pinch) ─────────────────────────────────────────────────

  void _onScaleStart(ScaleStartDetails details) {
    if (details.pointerCount < 2 || _selectedNodeName == null) return;
    final node = _findNodeByName(_selectedNodeName!);
    if (node != null) _pinchBaseScale = node.scale.x;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount < 2 || _selectedNodeName == null) return;
    final node = _findNodeByName(_selectedNodeName!);
    if (node == null) return;

    final newScale =
        (_pinchBaseScale * details.scale).clamp(_minScale, _maxScale);
    node.scale = vm.Vector3.all(newScale);
  }

  // ── Full 360° rotation via the 2-D joystick pad ───────────────────────────
  //
  //  dx > 0  →  rotate right  (yaw  +, around Y axis)
  //  dx < 0  →  rotate left   (yaw  -, around Y axis)
  //  dy > 0  →  tilt forward  (pitch+, around X axis)
  //  dy < 0  →  tilt backward (pitch-, around X axis)
  //
  //  No angular clamp: the euler decomposition wraps naturally, giving
  //  continuous 360° rotation on both axes.

  void _onRotationPadDrag(double dx, double dy) {
    if (_selectedNodeName == null) return;
    final node = _findNodeByName(_selectedNodeName!);
    if (node == null) return;

    final current = node.eulerAngles;
    node.eulerAngles = vm.Vector3(
      current.x + dy * _rotationSensitivity, // pitch  (up / down)
      current.y + dx * _rotationSensitivity, // yaw    (left / right)
      current.z, // roll   (unchanged)
    );
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  void _onLongPressArView() {
    if (_selectedNodeName == null) return;
    final node = _findNodeByName(_selectedNodeName!);
    if (node == null) return;
    final objectName = node.data?['name'] as String? ?? 'cet objet';
    _showDeleteConfirmation(node, objectName);
  }

  void _showDeleteConfirmation(ARNode node, String objectName) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'objet'),
        content: Text(
            'Voulez-vous supprimer «\u00a0$objectName\u00a0» de la scène ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) _deleteNode(node);
    });
  }

  void _deleteNode(ARNode node) {
    final anchor = _findAnchorForNode(node.name);
    if (anchor != null) {
      _arAnchorManager?.removeAnchor(anchor);
      _anchors.remove(anchor);
    } else {
      _arObjectManager?.removeNode(node);
    }
    setState(() {
      _nodes.remove(node);
      if (_selectedNodeName == node.name) _selectedNodeName = null;
    });
  }

  Future<void> _clearAll() async {
    for (final anchor in _anchors) {
      _arAnchorManager?.removeAnchor(anchor);
    }
    setState(() {
      _anchors.clear();
      _nodes.clear();
      _selectedNodeName = null;
    });
  }

  void _showError(String message) {
    _arSessionManager?.onError(message);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasSelection = _selectedNodeName != null && !_isPlacingObject;

    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButton(color: Colors.white),
          title: const Text(
            'Réalité Augmentée',
            style: TextStyle(color: Colors.white, shadows: [
              Shadow(blurRadius: 4, color: Colors.black54),
            ]),
          ),
          actions: [
            if (_nodes.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.white),
                tooltip: 'Tout effacer',
                onPressed: _clearAll,
              ),
          ],
        ),
        body: Stack(
          children: [
            // ── AR view — pinch-to-scale + long-press delete ──────────────
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              onLongPress: _onLongPressArView,
              child: ARView(
                onARViewCreated: _onARViewCreated,
                planeDetectionConfig:
                    PlaneDetectionConfig.horizontalAndVertical,
              ),
            ),

            // ── 2-D rotation joystick pad (bottom-right, when selected) ──
            if (hasSelection)
              Positioned(
                right: 16,
                bottom: 166,
                child: _RotationPad(onDrag: _onRotationPadDrag),
              ),

            // ── Surface hint (no object chosen from list yet) ─────────────
            if (_selectedObject == null) _buildScanHint(),

            // ── Placement hint (object chosen, waiting for surface tap) ───
            if (_selectedObject != null && !_isPlacingObject)
              _buildPlacementHint(),

            // ── Download / placement progress overlay ─────────────────────
            if (_isPlacingObject) _buildLoadingOverlay(),

            // ── Gesture hints (scale · rotate · delete) ───────────────────
            if (hasSelection) _buildSelectionHints(),

            // ── Bottom object list ────────────────────────────────────────
            Align(
              alignment: Alignment.bottomCenter,
              child: Object3dListPanel(
                selectedObject: _selectedObject,
                onObjectSelected: (obj) =>
                    setState(() => _selectedObject = obj),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper widgets ────────────────────────────────────────────────────────

  Widget _buildScanHint() {
    return Positioned(
      top: kToolbarHeight + MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Center(
        child: _InfoBadge(
          icon: Icons.crop_free,
          text: 'Pointez l\'appareil vers une surface plane',
        ),
      ),
    );
  }

  Widget _buildPlacementHint() {
    return Positioned(
      top: kToolbarHeight + MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Center(
        child: _InfoBadge(
          icon: Icons.touch_app,
          text:
              'Appuyez sur une surface pour placer «\u00a0${_selectedObject!.name}\u00a0»',
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildSelectionHints() {
    return Container();
    return Positioned(
      bottom: 166,
      left: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: const [
          _InfoBadge(icon: Icons.pinch, text: 'Pincez : redimensionner'),
          SizedBox(height: 6),
          _InfoBadge(
              icon: Icons.screen_rotation, text: 'Pavé droit : rotation 360°'),
          SizedBox(height: 6),
          _InfoBadge(icon: Icons.touch_app, text: 'Appui long : supprimer'),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.45),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            Text(
              'Chargement de l\'objet 3D…',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 2-D rotation joystick pad ─────────────────────────────────────────────────
//
// Horizontal drag  →  yaw   rotation (around Y, left / right 360°)
// Vertical drag    →  pitch rotation (around X, up / down 360°)

class _RotationPad extends StatelessWidget {
  final void Function(double dx, double dy) onDrag;

  const _RotationPad({required this.onDrag});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // onPanUpdate gives continuous dx/dy even when the finger moves diagonally.
      onPanUpdate: (details) => onDrag(details.delta.dx, details.delta.dy),
      child: Container(
        width: 116,
        height: 116,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.30),
            width: 1.5,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: const [
            // Center icon
            Icon(Icons.threesixty_sharp, color: Colors.white, size: 28),
            // Top arrow
            Positioned(
              top: 10,
              child: Icon(Icons.keyboard_arrow_up,
                  color: Colors.white70, size: 20),
            ),
            // Bottom arrow
            Positioned(
              bottom: 10,
              child: Icon(Icons.keyboard_arrow_down,
                  color: Colors.white70, size: 20),
            ),
            // Left arrow
            Positioned(
              left: 10,
              child: Icon(Icons.keyboard_arrow_left,
                  color: Colors.white70, size: 20),
            ),
            // Right arrow
            Positioned(
              right: 10,
              child: Icon(Icons.keyboard_arrow_right,
                  color: Colors.white70, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small reusable info badge ─────────────────────────────────────────────────

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _InfoBadge({
    required this.icon,
    required this.text,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: effectiveColor, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(color: effectiveColor, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
