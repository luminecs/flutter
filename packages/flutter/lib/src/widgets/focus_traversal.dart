// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import 'actions.dart';
import 'basic.dart';
import 'focus_manager.dart';
import 'focus_scope.dart';
import 'framework.dart';
import 'scroll_position.dart';
import 'scrollable.dart';

// Examples can assume:
// late BuildContext context;
// FocusNode focusNode = FocusNode();

// BuildContext/Element doesn't have a parent accessor, but it can be simulated
// with visitAncestorElements. _getAncestor is needed because
// context.getElementForInheritedWidgetOfExactType will return itself if it
// happens to be of the correct type. _getAncestor should be O(count), since we
// always return false at a specific ancestor. By default it returns the parent,
// which is O(1).
BuildContext? _getAncestor(BuildContext context, {int count = 1}) {
  BuildContext? target;
  context.visitAncestorElements((Element ancestor) {
    count--;
    if (count == 0) {
      target = ancestor;
      return false;
    }
    return true;
  });
  return target;
}

typedef TraversalRequestFocusCallback = void Function(
    FocusNode node, {
    ScrollPositionAlignmentPolicy? alignmentPolicy,
    double? alignment,
    Duration? duration,
    Curve? curve,
});

// A class to temporarily hold information about FocusTraversalGroups when
// sorting their contents.
class _FocusTraversalGroupInfo {
  _FocusTraversalGroupInfo(
    _FocusTraversalGroupNode? group, {
    FocusTraversalPolicy? defaultPolicy,
    List<FocusNode>? members,
  })  : groupNode = group,
        policy = group?.policy ?? defaultPolicy ?? ReadingOrderTraversalPolicy(),
        members = members ?? <FocusNode>[];

  final FocusNode? groupNode;
  final FocusTraversalPolicy policy;
  final List<FocusNode> members;
}

enum TraversalDirection {
  up,

  right,

  down,

  left,
}

enum TraversalEdgeBehavior {
  closedLoop,

  leaveFlutterView,
}

@immutable
abstract class FocusTraversalPolicy with Diagnosticable {
  const FocusTraversalPolicy({
    TraversalRequestFocusCallback? requestFocusCallback
  }) : requestFocusCallback = requestFocusCallback ?? defaultTraversalRequestFocusCallback;

  final TraversalRequestFocusCallback requestFocusCallback;

  static void defaultTraversalRequestFocusCallback(
    FocusNode node, {
    ScrollPositionAlignmentPolicy? alignmentPolicy,
    double? alignment,
    Duration? duration,
    Curve? curve,
  }) {
    node.requestFocus();
    Scrollable.ensureVisible(
      node.context!, alignment: alignment ?? 1.0,
      alignmentPolicy: alignmentPolicy ?? ScrollPositionAlignmentPolicy.explicit,
      duration: duration ?? Duration.zero,
      curve: curve ?? Curves.ease,
    );
  }

  FocusNode? findFirstFocus(FocusNode currentNode, {bool ignoreCurrentFocus = false}) {
    return _findInitialFocus(currentNode, ignoreCurrentFocus: ignoreCurrentFocus);
  }

  FocusNode findLastFocus(FocusNode currentNode, {bool ignoreCurrentFocus = false}) {
    return _findInitialFocus(currentNode, fromEnd: true, ignoreCurrentFocus: ignoreCurrentFocus);
  }

  FocusNode _findInitialFocus(FocusNode currentNode, {bool fromEnd = false, bool ignoreCurrentFocus = false}) {
    final FocusScopeNode scope = currentNode.nearestScope!;
    FocusNode? candidate = scope.focusedChild;
    if (ignoreCurrentFocus || candidate == null && scope.descendants.isNotEmpty) {
      final Iterable<FocusNode> sorted = _sortAllDescendants(scope, currentNode);
      if (sorted.isEmpty) {
        candidate = null;
      } else {
        candidate = fromEnd ? sorted.last : sorted.first;
      }
    }

    // If we still didn't find any candidate, use the current node as a
    // fallback.
    candidate ??= currentNode;
    return candidate;
  }

  FocusNode? findFirstFocusInDirection(FocusNode currentNode, TraversalDirection direction);

  @mustCallSuper
  void invalidateScopeData(FocusScopeNode node) {}

  @mustCallSuper
  void changedScope({FocusNode? node, FocusScopeNode? oldScope}) {}

  bool next(FocusNode currentNode) => _moveFocus(currentNode, forward: true);

  bool previous(FocusNode currentNode) => _moveFocus(currentNode, forward: false);

  bool inDirection(FocusNode currentNode, TraversalDirection direction);

  @protected
  Iterable<FocusNode> sortDescendants(Iterable<FocusNode> descendants, FocusNode currentNode);

  Map<FocusNode?, _FocusTraversalGroupInfo> _findGroups(FocusScopeNode scope, _FocusTraversalGroupNode? scopeGroupNode, FocusNode currentNode) {
    final FocusTraversalPolicy defaultPolicy = scopeGroupNode?.policy ?? ReadingOrderTraversalPolicy();
    final Map<FocusNode?, _FocusTraversalGroupInfo> groups = <FocusNode?, _FocusTraversalGroupInfo>{};
    for (final FocusNode node in scope.descendants) {
      final _FocusTraversalGroupNode? groupNode = FocusTraversalGroup._getGroupNode(node);
      // Group nodes need to be added to their parent's node, or to the "null"
      // node if no parent is found. This creates the hierarchy of group nodes
      // and makes it so the entire group is sorted along with the other members
      // of the parent group.
      if (node == groupNode) {
        // To find the parent of the group node, we need to skip over the parent
        // of the Focus node added in _FocusTraversalGroupState.build, and start
        // looking with that node's parent, since _getGroupNode will return the
        // node it was called on if it matches the type.
        final _FocusTraversalGroupNode? parentGroup = FocusTraversalGroup._getGroupNode(groupNode!.parent!);
        groups[parentGroup] ??= _FocusTraversalGroupInfo(parentGroup, members: <FocusNode>[], defaultPolicy: defaultPolicy);
        assert(!groups[parentGroup]!.members.contains(node));
        groups[parentGroup]!.members.add(groupNode);
        continue;
      }
      // Skip non-focusable and non-traversable nodes in the same way that
      // FocusScopeNode.traversalDescendants would.
      //
      // Current focused node needs to be in the group so that the caller can
      // find the next traversable node from the current focused node.
      if (node == currentNode || (node.canRequestFocus && !node.skipTraversal)) {
        groups[groupNode] ??= _FocusTraversalGroupInfo(groupNode, members: <FocusNode>[], defaultPolicy: defaultPolicy);
        assert(!groups[groupNode]!.members.contains(node));
        groups[groupNode]!.members.add(node);
      }
    }
    return groups;
  }

  // Sort all descendants, taking into account the FocusTraversalGroup
  // that they are each in, and filtering out non-traversable/focusable nodes.
  List<FocusNode> _sortAllDescendants(FocusScopeNode scope, FocusNode currentNode) {
    final _FocusTraversalGroupNode? scopeGroupNode = FocusTraversalGroup._getGroupNode(scope);
    // Build the sorting data structure, separating descendants into groups.
    final Map<FocusNode?, _FocusTraversalGroupInfo> groups = _findGroups(scope, scopeGroupNode, currentNode);

    // Sort the member lists using the individual policy sorts.
    for (final FocusNode? key in groups.keys) {
      final List<FocusNode> sortedMembers = groups[key]!.policy.sortDescendants(groups[key]!.members, currentNode).toList();
      groups[key]!.members.clear();
      groups[key]!.members.addAll(sortedMembers);
    }


    // Traverse the group tree, adding the children of members in the order they
    // appear in the member lists.
    final List<FocusNode> sortedDescendants = <FocusNode>[];
    void visitGroups(_FocusTraversalGroupInfo info) {
      for (final FocusNode node in info.members) {
        if (groups.containsKey(node)) {
          // This is a policy group focus node. Replace it with the members of
          // the corresponding policy group.
          visitGroups(groups[node]!);
        } else {
          sortedDescendants.add(node);
        }
      }
    }

    // Visit the children of the scope, if any.
    if (groups.isNotEmpty && groups.containsKey(scopeGroupNode)) {
      visitGroups(groups[scopeGroupNode]!);
    }

    // Remove the FocusTraversalGroup nodes themselves, which aren't focusable.
    // They were left in above because they were needed to find their members
    // during sorting.
    sortedDescendants.removeWhere((FocusNode node) {
      return node != currentNode && (!node.canRequestFocus || node.skipTraversal);
    });

    // Sanity check to make sure that the algorithm above doesn't diverge from
    // the one in FocusScopeNode.traversalDescendants in terms of which nodes it
    // finds.
    assert((){
      final Set<FocusNode> difference = sortedDescendants.toSet().difference(scope.traversalDescendants.toSet());
      if (currentNode.skipTraversal || !currentNode.canRequestFocus) {
        // The scope.traversalDescendants will not contain currentNode if it
        // skips traversal or not focusable.
        assert(
         difference.length == 1 && difference.contains(currentNode),
         'Sorted descendants contains different nodes than FocusScopeNode.traversalDescendants would. '
         'These are the different nodes: ${difference.where((FocusNode node) => node != currentNode)}',
        );
        return true;
      }
      assert(
        difference.isEmpty,
        'Sorted descendants contains different nodes than FocusScopeNode.traversalDescendants would. '
        'These are the different nodes: $difference',
      );
      return true;
    }());
    return sortedDescendants;
  }

  @protected
  bool _moveFocus(FocusNode currentNode, {required bool forward}) {
    final FocusScopeNode nearestScope = currentNode.nearestScope!;
    invalidateScopeData(nearestScope);
    FocusNode? focusedChild = nearestScope.focusedChild;
    if (focusedChild == null) {
      final FocusNode? firstFocus = forward ? findFirstFocus(currentNode) : findLastFocus(currentNode);
      if (firstFocus != null) {
        requestFocusCallback(
          firstFocus,
          alignmentPolicy: forward ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
        return true;
      }
    }
    focusedChild ??= nearestScope;
    final List<FocusNode> sortedNodes = _sortAllDescendants(nearestScope, focusedChild);

    assert(sortedNodes.contains(focusedChild));
    if (sortedNodes.length < 2) {
      // If there are no nodes to traverse to, like when descendantsAreTraversable
      // is false or skipTraversal for all the nodes is true.
      return false;
    }
    if (forward && focusedChild == sortedNodes.last) {
      switch (nearestScope.traversalEdgeBehavior) {
        case TraversalEdgeBehavior.leaveFlutterView:
          focusedChild.unfocus();
          return false;
        case TraversalEdgeBehavior.closedLoop:
          requestFocusCallback(sortedNodes.first, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
          return true;
      }
    }
    if (!forward && focusedChild == sortedNodes.first) {
      switch (nearestScope.traversalEdgeBehavior) {
        case TraversalEdgeBehavior.leaveFlutterView:
          focusedChild.unfocus();
          return false;
        case TraversalEdgeBehavior.closedLoop:
          requestFocusCallback(sortedNodes.last, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart);
          return true;
      }
    }

    final Iterable<FocusNode> maybeFlipped = forward ? sortedNodes : sortedNodes.reversed;
    FocusNode? previousNode;
    for (final FocusNode node in maybeFlipped) {
      if (previousNode == focusedChild) {
        requestFocusCallback(
          node,
          alignmentPolicy: forward ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
        return true;
      }
      previousNode = node;
    }
    return false;
  }
}

// A policy data object for use by the DirectionalFocusTraversalPolicyMixin so
// it can keep track of the traversal history.
class _DirectionalPolicyDataEntry {
  const _DirectionalPolicyDataEntry({required this.direction, required this.node});

  final TraversalDirection direction;
  final FocusNode node;
}

class _DirectionalPolicyData {
  const _DirectionalPolicyData({required this.history});

  final List<_DirectionalPolicyDataEntry> history;
}

mixin DirectionalFocusTraversalPolicyMixin on FocusTraversalPolicy {
  final Map<FocusScopeNode, _DirectionalPolicyData> _policyData = <FocusScopeNode, _DirectionalPolicyData>{};

  @override
  void invalidateScopeData(FocusScopeNode node) {
    super.invalidateScopeData(node);
    _policyData.remove(node);
  }

  @override
  void changedScope({FocusNode? node, FocusScopeNode? oldScope}) {
    super.changedScope(node: node, oldScope: oldScope);
    if (oldScope != null) {
      _policyData[oldScope]?.history.removeWhere((_DirectionalPolicyDataEntry entry) {
        return entry.node == node;
      });
    }
  }

  @override
  FocusNode? findFirstFocusInDirection(FocusNode currentNode, TraversalDirection direction) {
    switch (direction) {
      case TraversalDirection.up:
        // Find the bottom-most node so we can go up from there.
        return _sortAndFindInitial(currentNode, vertical: true, first: false);
      case TraversalDirection.down:
        // Find the top-most node so we can go down from there.
        return _sortAndFindInitial(currentNode, vertical: true, first: true);
      case TraversalDirection.left:
        // Find the right-most node so we can go left from there.
        return _sortAndFindInitial(currentNode, vertical: false, first: false);
      case TraversalDirection.right:
        // Find the left-most node so we can go right from there.
        return _sortAndFindInitial(currentNode, vertical: false, first: true);
    }
  }

  FocusNode? _sortAndFindInitial(FocusNode currentNode, {required bool vertical, required bool first}) {
    final Iterable<FocusNode> nodes = currentNode.nearestScope!.traversalDescendants;
    final List<FocusNode> sorted = nodes.toList();
    mergeSort<FocusNode>(sorted, compare: (FocusNode a, FocusNode b) {
      if (vertical) {
        if (first) {
          return a.rect.top.compareTo(b.rect.top);
        } else {
          return b.rect.bottom.compareTo(a.rect.bottom);
        }
      } else {
        if (first) {
          return a.rect.left.compareTo(b.rect.left);
        } else {
          return b.rect.right.compareTo(a.rect.right);
        }
      }
    });

    if (sorted.isNotEmpty) {
      return sorted.first;
    }

    return null;
  }

  static int _verticalCompare(Offset target, Offset a, Offset b) {
    return (a.dy - target.dy).abs().compareTo((b.dy - target.dy).abs());
  }

  static int _horizontalCompare(Offset target, Offset a, Offset b) {
    return (a.dx - target.dx).abs().compareTo((b.dx - target.dx).abs());
  }

  // Sort the ones that are closest to target vertically first, and if two are
  // the same vertical distance, pick the one that is closest horizontally.
  static Iterable<FocusNode> _sortByDistancePreferVertical(Offset target, Iterable<FocusNode> nodes) {
    final List<FocusNode> sorted = nodes.toList();
    mergeSort<FocusNode>(sorted, compare: (FocusNode nodeA, FocusNode nodeB) {
      final Offset a = nodeA.rect.center;
      final Offset b = nodeB.rect.center;
      final int vertical = _verticalCompare(target, a, b);
      if (vertical == 0) {
        return _horizontalCompare(target, a, b);
      }
      return vertical;
    });
    return sorted;
  }

  // Sort the ones that are closest horizontally first, and if two are the same
  // horizontal distance, pick the one that is closest vertically.
  static Iterable<FocusNode> _sortByDistancePreferHorizontal(Offset target, Iterable<FocusNode> nodes) {
    final List<FocusNode> sorted = nodes.toList();
    mergeSort<FocusNode>(sorted, compare: (FocusNode nodeA, FocusNode nodeB) {
      final Offset a = nodeA.rect.center;
      final Offset b = nodeB.rect.center;
      final int horizontal = _horizontalCompare(target, a, b);
      if (horizontal == 0) {
        return _verticalCompare(target, a, b);
      }
      return horizontal;
    });
    return sorted;
  }

  static int _verticalCompareClosestEdge(Offset target, Rect a, Rect b) {
    // Find which edge is closest to the target for each.
    final double aCoord = (a.top - target.dy).abs() < (a.bottom - target.dy).abs() ? a.top : a.bottom;
    final double bCoord = (b.top - target.dy).abs() < (b.bottom - target.dy).abs() ? b.top : b.bottom;
    return (aCoord - target.dy).abs().compareTo((bCoord - target.dy).abs());
  }

  static int _horizontalCompareClosestEdge(Offset target, Rect a, Rect b) {
    // Find which edge is closest to the target for each.
    final double aCoord = (a.left - target.dx).abs() < (a.right - target.dx).abs() ? a.left : a.right;
    final double bCoord = (b.left - target.dx).abs() < (b.right - target.dx).abs() ? b.left : b.right;
    return (aCoord - target.dx).abs().compareTo((bCoord - target.dx).abs());
  }

  // Sort the ones that have edges that are closest horizontally first, and if
  // two are the same horizontal distance, pick the one that is closest
  // vertically.
  static Iterable<FocusNode> _sortClosestEdgesByDistancePreferHorizontal(Offset target, Iterable<FocusNode> nodes) {
    final List<FocusNode> sorted = nodes.toList();
    mergeSort<FocusNode>(sorted, compare: (FocusNode nodeA, FocusNode nodeB) {
      final int horizontal = _horizontalCompareClosestEdge(target, nodeA.rect, nodeB.rect);
      if (horizontal == 0) {
        // If they're the same distance horizontally, pick the closest one
        // vertically.
        return _verticalCompare(target, nodeA.rect.center, nodeB.rect.center);
      }
      return horizontal;
    });
    return sorted;
  }

  // Sort the ones that have edges that are closest vertically first, and if
  // two are the same vertical distance, pick the one that is closest
  // horizontally.
  static Iterable<FocusNode> _sortClosestEdgesByDistancePreferVertical(Offset target, Iterable<FocusNode> nodes) {
    final List<FocusNode> sorted = nodes.toList();
    mergeSort<FocusNode>(sorted, compare: (FocusNode nodeA, FocusNode nodeB) {
      final int vertical = _verticalCompareClosestEdge(target, nodeA.rect, nodeB.rect);
      if (vertical == 0) {
        // If they're the same distance vertically, pick the closest one
        // horizontally.
        return _horizontalCompare(target, nodeA.rect.center, nodeB.rect.center);
      }
      return vertical;
    });
    return sorted;
  }

  // Sorts nodes from left to right horizontally, and removes nodes that are
  // either to the right of the left side of the target node if we're going
  // left, or to the left of the right side of the target node if we're going
  // right.
  //
  // This doesn't need to take into account directionality because it is
  // typically intending to actually go left or right, not in a reading
  // direction.
  Iterable<FocusNode> _sortAndFilterHorizontally(
    TraversalDirection direction,
    Rect target,
    Iterable<FocusNode> nodes,
  ) {
    assert(direction == TraversalDirection.left || direction == TraversalDirection.right);
    final Iterable<FocusNode> filtered;
    switch (direction) {
      case TraversalDirection.left:
        filtered = nodes.where((FocusNode node) => node.rect != target && node.rect.center.dx <= target.left);
      case TraversalDirection.right:
        filtered = nodes.where((FocusNode node) => node.rect != target && node.rect.center.dx >= target.right);
      case TraversalDirection.up:
      case TraversalDirection.down:
        throw ArgumentError('Invalid direction $direction');
    }
    final List<FocusNode> sorted = filtered.toList();
    // Sort all nodes from left to right.
    mergeSort<FocusNode>(sorted, compare: (FocusNode a, FocusNode b) => a.rect.center.dx.compareTo(b.rect.center.dx));
    return sorted;
  }

  // Sorts nodes from top to bottom vertically, and removes nodes that are
  // either below the top of the target node if we're going up, or above the
  // bottom of the target node if we're going down.
  Iterable<FocusNode> _sortAndFilterVertically(
    TraversalDirection direction,
    Rect target,
    Iterable<FocusNode> nodes,
  ) {
    assert(direction == TraversalDirection.up || direction == TraversalDirection.down);
    final Iterable<FocusNode> filtered;
    switch (direction) {
      case TraversalDirection.up:
        filtered = nodes.where((FocusNode node) => node.rect != target && node.rect.center.dy <= target.top);
      case TraversalDirection.down:
        filtered = nodes.where((FocusNode node) => node.rect != target && node.rect.center.dy >= target.bottom);
      case TraversalDirection.left:
      case TraversalDirection.right:
        throw ArgumentError('Invalid direction $direction');
    }
    final List<FocusNode> sorted = filtered.toList();
    mergeSort<FocusNode>(sorted, compare: (FocusNode a, FocusNode b) => a.rect.center.dy.compareTo(b.rect.center.dy));
    return sorted;
  }

  // Updates the policy data to keep the previously visited node so that we can
  // avoid hysteresis when we change directions in navigation.
  //
  // Returns true if focus was requested on a previous node.
  bool _popPolicyDataIfNeeded(TraversalDirection direction, FocusScopeNode nearestScope, FocusNode focusedChild) {
    final _DirectionalPolicyData? policyData = _policyData[nearestScope];
    if (policyData != null && policyData.history.isNotEmpty && policyData.history.first.direction != direction) {
      if (policyData.history.last.node.parent == null) {
        // If a node has been removed from the tree, then we should stop
        // referencing it and reset the scope data so that we don't try and
        // request focus on it. This can happen in slivers where the rendered
        // node has been unmounted. This has the side effect that hysteresis
        // might not be avoided when items that go off screen get unmounted.
        invalidateScopeData(nearestScope);
        return false;
      }

      // Returns true if successfully popped the history.
      bool popOrInvalidate(TraversalDirection direction) {
        final FocusNode lastNode = policyData.history.removeLast().node;
        if (Scrollable.maybeOf(lastNode.context!) != Scrollable.maybeOf(primaryFocus!.context!)) {
          invalidateScopeData(nearestScope);
          return false;
        }
        final ScrollPositionAlignmentPolicy alignmentPolicy;
        switch (direction) {
          case TraversalDirection.up:
          case TraversalDirection.left:
            alignmentPolicy = ScrollPositionAlignmentPolicy.keepVisibleAtStart;
          case TraversalDirection.right:
          case TraversalDirection.down:
            alignmentPolicy = ScrollPositionAlignmentPolicy.keepVisibleAtEnd;
        }
        requestFocusCallback(
          lastNode,
          alignmentPolicy: alignmentPolicy,
        );
        return true;
      }

      switch (direction) {
        case TraversalDirection.down:
        case TraversalDirection.up:
          switch (policyData.history.first.direction) {
            case TraversalDirection.left:
            case TraversalDirection.right:
              // Reset the policy data if we change directions.
              invalidateScopeData(nearestScope);
            case TraversalDirection.up:
            case TraversalDirection.down:
              if (popOrInvalidate(direction)) {
                return true;
              }
          }
        case TraversalDirection.left:
        case TraversalDirection.right:
          switch (policyData.history.first.direction) {
            case TraversalDirection.left:
            case TraversalDirection.right:
              if (popOrInvalidate(direction)) {
                return true;
              }
            case TraversalDirection.up:
            case TraversalDirection.down:
              // Reset the policy data if we change directions.
              invalidateScopeData(nearestScope);
          }
      }
    }
    if (policyData != null && policyData.history.isEmpty) {
      invalidateScopeData(nearestScope);
    }
    return false;
  }

  void _pushPolicyData(TraversalDirection direction, FocusScopeNode nearestScope, FocusNode focusedChild) {
    final _DirectionalPolicyData? policyData = _policyData[nearestScope];
    final _DirectionalPolicyDataEntry newEntry = _DirectionalPolicyDataEntry(node: focusedChild, direction: direction);
    if (policyData != null) {
      policyData.history.add(newEntry);
    } else {
      _policyData[nearestScope] = _DirectionalPolicyData(history: <_DirectionalPolicyDataEntry>[newEntry]);
    }
  }

  @mustCallSuper
  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) {
    final FocusScopeNode nearestScope = currentNode.nearestScope!;
    final FocusNode? focusedChild = nearestScope.focusedChild;
    if (focusedChild == null) {
      final FocusNode firstFocus = findFirstFocusInDirection(currentNode, direction) ?? currentNode;
      switch (direction) {
        case TraversalDirection.up:
        case TraversalDirection.left:
          requestFocusCallback(
            firstFocus,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
          );
        case TraversalDirection.right:
        case TraversalDirection.down:
          requestFocusCallback(
            firstFocus,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          );
      }
      return true;
    }
    if (_popPolicyDataIfNeeded(direction, nearestScope, focusedChild)) {
      return true;
    }
    FocusNode? found;
    final ScrollableState? focusedScrollable = Scrollable.maybeOf(focusedChild.context!);
    switch (direction) {
      case TraversalDirection.down:
      case TraversalDirection.up:
        Iterable<FocusNode> eligibleNodes = _sortAndFilterVertically(direction, focusedChild.rect, nearestScope.traversalDescendants);
        if (eligibleNodes.isEmpty) {
          break;
        }
        if (focusedScrollable != null && !focusedScrollable.position.atEdge) {
          final Iterable<FocusNode> filteredEligibleNodes = eligibleNodes.where((FocusNode node) => Scrollable.maybeOf(node.context!) == focusedScrollable);
          if (filteredEligibleNodes.isNotEmpty) {
            eligibleNodes = filteredEligibleNodes;
          }
        }
        if (direction == TraversalDirection.up) {
          eligibleNodes = eligibleNodes.toList().reversed;
        }
        // Find any nodes that intersect the band of the focused child.
        final Rect band = Rect.fromLTRB(focusedChild.rect.left, -double.infinity, focusedChild.rect.right, double.infinity);
        final Iterable<FocusNode> inBand = eligibleNodes.where((FocusNode node) => !node.rect.intersect(band).isEmpty);
        if (inBand.isNotEmpty) {
          found = _sortByDistancePreferVertical(focusedChild.rect.center, inBand).first;
          break;
        }
        // Only out-of-band targets are eligible, so pick the one that is
        // closest to the center line horizontally, and if any are the same
        // distance horizontally, pick the closest one of those vertically.
        found = _sortClosestEdgesByDistancePreferHorizontal(focusedChild.rect.center, eligibleNodes).first;
      case TraversalDirection.right:
      case TraversalDirection.left:
        Iterable<FocusNode> eligibleNodes = _sortAndFilterHorizontally(direction, focusedChild.rect, nearestScope.traversalDescendants);
        if (eligibleNodes.isEmpty) {
          break;
        }
        if (focusedScrollable != null && !focusedScrollable.position.atEdge) {
          final Iterable<FocusNode> filteredEligibleNodes = eligibleNodes.where((FocusNode node) => Scrollable.maybeOf(node.context!) == focusedScrollable);
          if (filteredEligibleNodes.isNotEmpty) {
            eligibleNodes = filteredEligibleNodes;
          }
        }
        if (direction == TraversalDirection.left) {
          eligibleNodes = eligibleNodes.toList().reversed;
        }
        // Find any nodes that intersect the band of the focused child.
        final Rect band = Rect.fromLTRB(-double.infinity, focusedChild.rect.top, double.infinity, focusedChild.rect.bottom);
        final Iterable<FocusNode> inBand = eligibleNodes.where((FocusNode node) => !node.rect.intersect(band).isEmpty);
        if (inBand.isNotEmpty) {
          found = _sortByDistancePreferHorizontal(focusedChild.rect.center, inBand).first;
          break;
        }
        // Only out-of-band targets are eligible, so pick the one that is
        // closest to the center line vertically, and if any are the same
        // distance vertically, pick the closest one of those horizontally.
        found = _sortClosestEdgesByDistancePreferVertical(focusedChild.rect.center, eligibleNodes).first;
    }
    if (found != null) {
      _pushPolicyData(direction, nearestScope, focusedChild);
      switch (direction) {
        case TraversalDirection.up:
        case TraversalDirection.left:
          requestFocusCallback(
            found,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
          );
        case TraversalDirection.down:
        case TraversalDirection.right:
          requestFocusCallback(
            found,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          );
      }
      return true;
    }
    return false;
  }
}

class WidgetOrderTraversalPolicy extends FocusTraversalPolicy with DirectionalFocusTraversalPolicyMixin {
  WidgetOrderTraversalPolicy({super.requestFocusCallback});
  @override
  Iterable<FocusNode> sortDescendants(Iterable<FocusNode> descendants, FocusNode currentNode) => descendants;
}

// This class exists mainly for efficiency reasons: the rect is copied out of
// the node, because it will be accessed many times in the reading order
// algorithm, and the FocusNode.rect accessor does coordinate transformation. If
// not for this optimization, it could just be removed, and the node used
// directly.
//
// It's also a convenient place to put some utility functions having to do with
// the sort data.
class _ReadingOrderSortData with Diagnosticable {
  _ReadingOrderSortData(this.node)
      : rect = node.rect,
        directionality = _findDirectionality(node.context!);

  final TextDirection? directionality;
  final Rect rect;
  final FocusNode node;

  // Find the directionality in force for a build context without creating a
  // dependency.
  static TextDirection? _findDirectionality(BuildContext context) {
    return context.getInheritedWidgetOfExactType<Directionality>()?.textDirection;
  }

  static TextDirection? commonDirectionalityOf(List<_ReadingOrderSortData> list) {
    final Iterable<Set<Directionality>> allAncestors = list.map<Set<Directionality>>((_ReadingOrderSortData member) => member.directionalAncestors.toSet());
    Set<Directionality>? common;
    for (final Set<Directionality> ancestorSet in allAncestors) {
      common ??= ancestorSet;
      common = common.intersection(ancestorSet);
    }
    if (common!.isEmpty) {
      // If there is no common ancestor, then arbitrarily pick the
      // directionality of the first group, which is the equivalent of the
      // "first strongly typed" item in a bidirectional algorithm.
      return list.first.directionality;
    }
    // Find the closest common ancestor. The memberAncestors list contains the
    // ancestors for all members, but the first member's ancestry was
    // added in order from nearest to furthest, so we can still use that
    // to determine the closest one.
    return list.first.directionalAncestors.firstWhere(common.contains).textDirection;
  }

  static void sortWithDirectionality(List<_ReadingOrderSortData> list, TextDirection directionality) {
    mergeSort<_ReadingOrderSortData>(list, compare: (_ReadingOrderSortData a, _ReadingOrderSortData b) {
      switch (directionality) {
        case TextDirection.ltr:
          return a.rect.left.compareTo(b.rect.left);
        case TextDirection.rtl:
          return b.rect.right.compareTo(a.rect.right);
      }
    });
  }

  Iterable<Directionality> get directionalAncestors {
    List<Directionality> getDirectionalityAncestors(BuildContext context) {
      final List<Directionality> result = <Directionality>[];
      InheritedElement? directionalityElement = context.getElementForInheritedWidgetOfExactType<Directionality>();
      while (directionalityElement != null) {
        result.add(directionalityElement.widget as Directionality);
        directionalityElement = _getAncestor(directionalityElement)?.getElementForInheritedWidgetOfExactType<Directionality>();
      }
      return result;
    }

    _directionalAncestors ??= getDirectionalityAncestors(node.context!);
    return _directionalAncestors!;
  }

  List<Directionality>? _directionalAncestors;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TextDirection>('directionality', directionality));
    properties.add(StringProperty('name', node.debugLabel, defaultValue: null));
    properties.add(DiagnosticsProperty<Rect>('rect', rect));
  }
}

// A class for containing group data while sorting in reading order while taking
// into account the ambient directionality.
class _ReadingOrderDirectionalGroupData with Diagnosticable {
  _ReadingOrderDirectionalGroupData(this.members);

  final List<_ReadingOrderSortData> members;

  TextDirection? get directionality => members.first.directionality;

  Rect? _rect;
  Rect get rect {
    if (_rect == null) {
      for (final Rect rect in members.map<Rect>((_ReadingOrderSortData data) => data.rect)) {
        _rect ??= rect;
        _rect = _rect!.expandToInclude(rect);
      }
    }
    return _rect!;
  }

  List<Directionality> get memberAncestors {
    if (_memberAncestors == null) {
      _memberAncestors = <Directionality>[];
      for (final _ReadingOrderSortData member in members) {
        _memberAncestors!.addAll(member.directionalAncestors);
      }
    }
    return _memberAncestors!;
  }

  List<Directionality>? _memberAncestors;

  static void sortWithDirectionality(List<_ReadingOrderDirectionalGroupData> list, TextDirection directionality) {
    mergeSort<_ReadingOrderDirectionalGroupData>(list, compare: (_ReadingOrderDirectionalGroupData a, _ReadingOrderDirectionalGroupData b) {
      switch (directionality) {
        case TextDirection.ltr:
          return a.rect.left.compareTo(b.rect.left);
        case TextDirection.rtl:
          return b.rect.right.compareTo(a.rect.right);
      }
    });
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TextDirection>('directionality', directionality));
    properties.add(DiagnosticsProperty<Rect>('rect', rect));
    properties.add(IterableProperty<String>('members', members.map<String>((_ReadingOrderSortData member) {
      return '"${member.node.debugLabel}"(${member.rect})';
    })));
  }
}

class ReadingOrderTraversalPolicy extends FocusTraversalPolicy with DirectionalFocusTraversalPolicyMixin {
  ReadingOrderTraversalPolicy({super.requestFocusCallback});

  // Collects the given candidates into groups by directionality. The candidates
  // have already been sorted as if they all had the directionality of the
  // nearest Directionality ancestor.
  List<_ReadingOrderDirectionalGroupData> _collectDirectionalityGroups(Iterable<_ReadingOrderSortData> candidates) {
    TextDirection? currentDirection = candidates.first.directionality;
    List<_ReadingOrderSortData> currentGroup = <_ReadingOrderSortData>[];
    final List<_ReadingOrderDirectionalGroupData> result = <_ReadingOrderDirectionalGroupData>[];
    // Split candidates into runs of the same directionality.
    for (final _ReadingOrderSortData candidate in candidates) {
      if (candidate.directionality == currentDirection) {
        currentGroup.add(candidate);
        continue;
      }
      currentDirection = candidate.directionality;
      result.add(_ReadingOrderDirectionalGroupData(currentGroup));
      currentGroup = <_ReadingOrderSortData>[candidate];
    }
    if (currentGroup.isNotEmpty) {
      result.add(_ReadingOrderDirectionalGroupData(currentGroup));
    }
    // Sort each group separately. Each group has the same directionality.
    for (final _ReadingOrderDirectionalGroupData bandGroup in result) {
      if (bandGroup.members.length == 1) {
        continue; // No need to sort one node.
      }
      _ReadingOrderSortData.sortWithDirectionality(bandGroup.members, bandGroup.directionality!);
    }
    return result;
  }

  _ReadingOrderSortData _pickNext(List<_ReadingOrderSortData> candidates) {
    // Find the topmost node by sorting on the top of the rectangles.
    mergeSort<_ReadingOrderSortData>(candidates, compare: (_ReadingOrderSortData a, _ReadingOrderSortData b) => a.rect.top.compareTo(b.rect.top));
    final _ReadingOrderSortData topmost = candidates.first;

    // Find the candidates that are in the same horizontal band as the current one.
    List<_ReadingOrderSortData> inBand(_ReadingOrderSortData current, Iterable<_ReadingOrderSortData> candidates) {
      final Rect band = Rect.fromLTRB(double.negativeInfinity, current.rect.top, double.infinity, current.rect.bottom);
      return candidates.where((_ReadingOrderSortData item) {
        return !item.rect.intersect(band).isEmpty;
      }).toList();
    }

    final List<_ReadingOrderSortData> inBandOfTop = inBand(topmost, candidates);
    // It has to have at least topmost in it if the topmost is not degenerate.
    assert(topmost.rect.isEmpty || inBandOfTop.isNotEmpty);

    // The topmost rect is in a band by itself, so just return that one.
    if (inBandOfTop.length <= 1) {
      return topmost;
    }

    // Now that we know there are others in the same band as the topmost, then pick
    // the one at the beginning, depending on the text direction in force.

    // Find out the directionality of the nearest common Directionality
    // ancestor for all nodes. This provides a base directionality to use for
    // the ordering of the groups.
    final TextDirection? nearestCommonDirectionality = _ReadingOrderSortData.commonDirectionalityOf(inBandOfTop);

    // Do an initial common-directionality-based sort to get consistent geometric
    // ordering for grouping into directionality groups. It has to use the
    // common directionality to be able to group into sane groups for the
    // given directionality, since rectangles can overlap and give different
    // results for different directionalities.
    _ReadingOrderSortData.sortWithDirectionality(inBandOfTop, nearestCommonDirectionality!);

    // Collect the top band into internally sorted groups with shared directionality.
    final List<_ReadingOrderDirectionalGroupData> bandGroups = _collectDirectionalityGroups(inBandOfTop);
    if (bandGroups.length == 1) {
      // There's only one directionality group, so just send back the first
      // one in that group, since it's already sorted.
      return bandGroups.first.members.first;
    }

    // Sort the groups based on the common directionality and bounding boxes.
    _ReadingOrderDirectionalGroupData.sortWithDirectionality(bandGroups, nearestCommonDirectionality);
    return bandGroups.first.members.first;
  }

  // Sorts the list of nodes based on their geometry into the desired reading
  // order based on the directionality of the context for each node.
  @override
  Iterable<FocusNode> sortDescendants(Iterable<FocusNode> descendants, FocusNode currentNode) {
    if (descendants.length <= 1) {
      return descendants;
    }

    final List<_ReadingOrderSortData> data = <_ReadingOrderSortData>[
      for (final FocusNode node in descendants) _ReadingOrderSortData(node),
    ];

    final List<FocusNode> sortedList = <FocusNode>[];
    final List<_ReadingOrderSortData> unplaced = data;

    // Pick the initial widget as the one that is at the beginning of the band
    // of the topmost, or the topmost, if there are no others in its band.
    _ReadingOrderSortData current = _pickNext(unplaced);
    sortedList.add(current.node);
    unplaced.remove(current);

    // Go through each node, picking the next one after eliminating the previous
    // one, since removing the previously picked node will expose a new band in
    // which to choose candidates.
    while (unplaced.isNotEmpty) {
      final _ReadingOrderSortData next = _pickNext(unplaced);
      current = next;
      sortedList.add(current.node);
      unplaced.remove(current);
    }
    return sortedList;
  }
}

@immutable
abstract class FocusOrder with Diagnosticable implements Comparable<FocusOrder> {
  const FocusOrder();

  @override
  @nonVirtual
  int compareTo(FocusOrder other) {
    assert(
      runtimeType == other.runtimeType,
      "The sorting algorithm must not compare incomparable keys, since they don't "
      'know how to order themselves relative to each other. Comparing $this with $other',
    );
    return doCompare(other);
  }

  @protected
  int doCompare(covariant FocusOrder other);
}

class NumericFocusOrder extends FocusOrder {
  const NumericFocusOrder(this.order);

  final double order;

  @override
  int doCompare(NumericFocusOrder other) => order.compareTo(other.order);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('order', order));
  }
}

class LexicalFocusOrder extends FocusOrder {
  const LexicalFocusOrder(this.order);

  final String order;

  @override
  int doCompare(LexicalFocusOrder other) => order.compareTo(other.order);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('order', order));
  }
}

// Used to help sort the focus nodes in an OrderedFocusTraversalPolicy.
class _OrderedFocusInfo {
  const _OrderedFocusInfo({required this.node, required this.order});

  final FocusNode node;
  final FocusOrder order;
}

class OrderedTraversalPolicy extends FocusTraversalPolicy with DirectionalFocusTraversalPolicyMixin {
  OrderedTraversalPolicy({this.secondary, super.requestFocusCallback});

  final FocusTraversalPolicy? secondary;

  @override
  Iterable<FocusNode> sortDescendants(Iterable<FocusNode> descendants, FocusNode currentNode) {
    final FocusTraversalPolicy secondaryPolicy = secondary ?? ReadingOrderTraversalPolicy();
    final Iterable<FocusNode> sortedDescendants = secondaryPolicy.sortDescendants(descendants, currentNode);
    final List<FocusNode> unordered = <FocusNode>[];
    final List<_OrderedFocusInfo> ordered = <_OrderedFocusInfo>[];
    for (final FocusNode node in sortedDescendants) {
      final FocusOrder? order = FocusTraversalOrder.maybeOf(node.context!);
      if (order != null) {
        ordered.add(_OrderedFocusInfo(node: node, order: order));
      } else {
        unordered.add(node);
      }
    }
    mergeSort<_OrderedFocusInfo>(ordered, compare: (_OrderedFocusInfo a, _OrderedFocusInfo b) {
      assert(
        a.order.runtimeType == b.order.runtimeType,
        'When sorting nodes for determining focus order, the order (${a.order}) of '
        "node ${a.node}, isn't the same type as the order (${b.order}) of ${b.node}. "
        "Incompatible order types can't be compared. Use a FocusTraversalGroup to group "
        'similar orders together.',
      );
      return a.order.compareTo(b.order);
    });
    return ordered.map<FocusNode>((_OrderedFocusInfo info) => info.node).followedBy(unordered);
  }
}

class FocusTraversalOrder extends InheritedWidget {
  const FocusTraversalOrder({super.key, required this.order, required super.child});

  final FocusOrder order;

  static FocusOrder of(BuildContext context) {
    final FocusTraversalOrder? marker = context.getInheritedWidgetOfExactType<FocusTraversalOrder>();
    assert(() {
      if (marker == null) {
        throw FlutterError(
          'FocusTraversalOrder.of() was called with a context that '
          'does not contain a FocusTraversalOrder widget. No TraversalOrder widget '
          'ancestor could be found starting from the context that was passed to '
          'FocusTraversalOrder.of().\n'
          'The context used was:\n'
          '  $context',
        );
      }
      return true;
    }());
    return marker!.order;
  }

  static FocusOrder? maybeOf(BuildContext context) {
    final FocusTraversalOrder? marker = context.getInheritedWidgetOfExactType<FocusTraversalOrder>();
    return marker?.order;
  }

  // Since the order of traversal doesn't affect display of anything, we don't
  // need to force a rebuild of anything that depends upon it.
  @override
  bool updateShouldNotify(InheritedWidget oldWidget) => false;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<FocusOrder>('order', order));
  }
}

class FocusTraversalGroup extends StatefulWidget {
  FocusTraversalGroup({
    super.key,
    FocusTraversalPolicy? policy,
    this.descendantsAreFocusable = true,
    this.descendantsAreTraversable = true,
    required this.child,
  }) : policy = policy ?? ReadingOrderTraversalPolicy();

  final FocusTraversalPolicy policy;

  final bool descendantsAreFocusable;

  final bool descendantsAreTraversable;

  final Widget child;

  static FocusTraversalPolicy? maybeOfNode(FocusNode node) {
    return _getGroupNode(node)?.policy;
  }

  static _FocusTraversalGroupNode? _getGroupNode(FocusNode node) {
    while (node.parent != null) {
      if (node.context == null) {
        return null;
      }
      if (node is _FocusTraversalGroupNode) {
        return node;
      }
      node = node.parent!;
    }
    return null;
  }

  static FocusTraversalPolicy of(BuildContext context) {
    final FocusTraversalPolicy? policy = maybeOf(context);
    assert(() {
      if (policy == null) {
        throw FlutterError(
          'Unable to find a Focus or FocusScope widget in the given context, or the FocusNode '
          'from with the widget that was found is not associated with a FocusTraversalPolicy.\n'
          'FocusTraversalGroup.of() was called with a context that does not contain a '
          'Focus or FocusScope widget, or there was no FocusTraversalPolicy in effect.\n'
          'This can happen if there is not a FocusTraversalGroup that defines the policy, '
          'or if the context comes from a widget that is above the WidgetsApp, MaterialApp, '
          'or CupertinoApp widget (those widgets introduce an implicit default policy) \n'
          'The context used was:\n'
          '  $context',
        );
      }
      return true;
    }());
    return policy!;
  }

  static FocusTraversalPolicy? maybeOf(BuildContext context) {
    final FocusNode? node = Focus.maybeOf(context, scopeOk: true, createDependency: false);
    if (node == null) {
      return null;
    }
    return FocusTraversalGroup.maybeOfNode(node);
  }

  @override
  State<FocusTraversalGroup> createState() => _FocusTraversalGroupState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<FocusTraversalPolicy>('policy', policy));
  }
}

// A special focus node subclass that only FocusTraversalGroup uses so that it
// can be used to cache the policy in the focus tree, and so that the traversal
// code can find groups in the focus tree.
class _FocusTraversalGroupNode extends FocusNode {
  _FocusTraversalGroupNode({
    super.debugLabel,
    required this.policy,
  }) {
    if (kFlutterMemoryAllocationsEnabled) {
      ChangeNotifier.maybeDispatchObjectCreation(this);
    }
  }

  FocusTraversalPolicy policy;
}

class _FocusTraversalGroupState extends State<FocusTraversalGroup> {
  // The internal focus node used to collect the children of this node into a
  // group, and to provide a context for the traversal algorithm to sort the
  // group with. It's a special subclass of FocusNode just so that it can be
  // identified when walking the focus tree during traversal, and hold the
  // current policy.
  late final _FocusTraversalGroupNode focusNode = _FocusTraversalGroupNode(
    debugLabel: 'FocusTraversalGroup',
    policy: widget.policy,
  );

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget (FocusTraversalGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.policy != widget.policy) {
      focusNode.policy = widget.policy;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      descendantsAreFocusable: widget.descendantsAreFocusable,
      descendantsAreTraversable: widget.descendantsAreTraversable,
      child: widget.child,
    );
  }
}

class RequestFocusIntent extends Intent {
  const RequestFocusIntent(this.focusNode, {
    TraversalRequestFocusCallback? requestFocusCallback
  }) : requestFocusCallback = requestFocusCallback ?? FocusTraversalPolicy.defaultTraversalRequestFocusCallback;

  final TraversalRequestFocusCallback requestFocusCallback;

  final FocusNode focusNode;
}

class RequestFocusAction extends Action<RequestFocusIntent> {

  @override
  void invoke(RequestFocusIntent intent) {
    intent.requestFocusCallback(intent.focusNode);
  }
}

class NextFocusIntent extends Intent {
  const NextFocusIntent();
}

class NextFocusAction extends Action<NextFocusIntent> {
  @override
  bool invoke(NextFocusIntent intent) {
    return primaryFocus!.nextFocus();
  }

  @override
  KeyEventResult toKeyEventResult(NextFocusIntent intent, bool invokeResult) {
    return invokeResult ? KeyEventResult.handled : KeyEventResult.skipRemainingHandlers;
  }
}

class PreviousFocusIntent extends Intent {
  const PreviousFocusIntent();
}

class PreviousFocusAction extends Action<PreviousFocusIntent> {
  @override
  bool invoke(PreviousFocusIntent intent) {
    return primaryFocus!.previousFocus();
  }

  @override
  KeyEventResult toKeyEventResult(PreviousFocusIntent intent, bool invokeResult) {
    return invokeResult ? KeyEventResult.handled : KeyEventResult.skipRemainingHandlers;
  }
}

class DirectionalFocusIntent extends Intent {
  const DirectionalFocusIntent(this.direction, {this.ignoreTextFields = true});

  final TraversalDirection direction;

  final bool ignoreTextFields;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<TraversalDirection>('direction', direction));
  }
}

class DirectionalFocusAction extends Action<DirectionalFocusIntent> {
  DirectionalFocusAction() : _isForTextField = false;

  DirectionalFocusAction.forTextField() : _isForTextField = true;

  // Whether this action is defined in a text field.
  final bool _isForTextField;
  @override
  void invoke(DirectionalFocusIntent intent) {
    if (!intent.ignoreTextFields || !_isForTextField) {
      primaryFocus!.focusInDirection(intent.direction);
    }
  }
}

class ExcludeFocusTraversal extends StatelessWidget {
  const ExcludeFocusTraversal({
    super.key,
    this.excluding = true,
    required this.child,
  });

  final bool excluding;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      descendantsAreTraversable: !excluding,
      child: child,
    );
  }
}