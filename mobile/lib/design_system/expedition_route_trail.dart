import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/core/localization/app_localizations_extension.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

class ExpeditionRouteTrailNode {
  const ExpeditionRouteTrailNode({
    required this.nodeId,
    required this.nodeName,
    required this.state,
  });

  final String nodeId;
  final String nodeName;
  final String state;

  bool get isCurrent => state == 'CURRENT';
  bool get isCompleted => state == 'COMPLETED';
}

/// A code-native map of the server-authored trail for one expedition journey.
///
/// The widget preserves the accepted node order and literal states. It never
/// adds future topology, predicts a branch or derives progress from node IDs.
class ExpeditionRouteTrail extends StatelessWidget {
  const ExpeditionRouteTrail({
    super.key,
    required this.nodes,
    this.height = 104,
  });

  final List<ExpeditionRouteTrailNode> nodes;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return const SizedBox.shrink(key: Key('expedition-route-trail-empty'));
    }

    final ExpeditionRouteTrailNode terminal = nodes.last;
    final String routeKey =
        'expedition-route-trail-${nodes.length}-'
        '${terminal.state.toLowerCase()}';
    return Semantics(
      key: Key(routeKey),
      container: true,
      label: context.l10n.expeditionRouteTrailSemantics(
        nodes.length,
        terminal.nodeName,
      ),
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: SingleChildScrollView(
            key: const Key('expedition-route-trail-scroll'),
            scrollDirection: Axis.horizontal,
            reverse: true,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(children: _routeChildren()),
          ),
        ),
      ),
    );
  }

  List<Widget> _routeChildren() {
    final List<Widget> children = <Widget>[];
    for (int index = 0; index < nodes.length; index += 1) {
      if (index > 0) {
        children.add(const _RouteConnector());
      }
      children.add(_RouteNode(node: nodes[index]));
    }
    return children;
  }
}

class _RouteConnector extends StatelessWidget {
  const _RouteConnector();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('expedition-route-trail-connector'),
      width: 34,
      height: 3,
      margin: const EdgeInsets.only(bottom: 32),
      decoration: BoxDecoration(
        color: context.walkingRpgPalette.routeLine,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class _RouteNode extends StatelessWidget {
  const _RouteNode({required this.node});

  final ExpeditionRouteTrailNode node;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final WalkingRpgPalette palette = context.walkingRpgPalette;
    final Color accent;
    final IconData icon;
    if (node.isCurrent) {
      accent = palette.energy;
      icon = Icons.my_location;
    } else if (node.isCompleted) {
      accent = palette.resonance;
      icon = Icons.flag_outlined;
    } else {
      accent = colors.primary;
      icon = Icons.check_rounded;
    }
    final String nodeKey =
        'expedition-route-node-${node.nodeId}-${node.state.toLowerCase()}';

    return SizedBox(
      key: Key(nodeKey),
      width: 88,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.alphaBlend(
                accent.withValues(alpha: 0.16),
                colors.surfaceContainerHigh,
              ),
              border: Border.all(color: accent, width: 2),
              boxShadow: _shadows(accent),
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(height: 8),
          Text(
            node.nodeName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: node.isCurrent || node.isCompleted
                  ? colors.onSurface
                  : colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  List<BoxShadow> _shadows(Color accent) {
    if (!node.isCurrent) {
      return const <BoxShadow>[];
    }
    return <BoxShadow>[
      BoxShadow(
        color: accent.withValues(alpha: 0.26),
        blurRadius: 12,
      ),
    ];
  }
}
