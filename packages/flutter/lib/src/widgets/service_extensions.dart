enum WidgetsServiceExtensions {
  debugDumpApp,

  debugDumpFocusTree,

  showPerformanceOverlay,

  didSendFirstFrameEvent,

  didSendFirstFrameRasterizedEvent,

  fastReassemble,

  profileWidgetBuilds,

  profileUserWidgetBuilds,

  debugAllowBanner,
}

enum WidgetInspectorServiceExtensions {
  structuredErrors,

  show,

  trackRebuildDirtyWidgets,

  trackRepaintWidgets,

  disposeAllGroups,

  disposeGroup,

  isWidgetTreeReady,

  disposeId,

  @Deprecated(
    'Use addPubRootDirectories instead. '
    'This feature was deprecated after v3.1.0-9.0.pre.',
  )
  setPubRootDirectories,

  addPubRootDirectories,

  removePubRootDirectories,

  getPubRootDirectories,

  setSelectionById,

  getParentChain,

  getProperties,

  getChildren,

  getChildrenSummaryTree,

  getChildrenDetailsSubtree,

  getRootWidget,

  getRootWidgetSummaryTree,

  getRootWidgetSummaryTreeWithPreviews,

  getDetailsSubtree,

  getSelectedWidget,

  getSelectedSummaryWidget,

  isWidgetCreationTracked,

  screenshot,

  getLayoutExplorerNode,

  setFlexFit,

  setFlexFactor,

  setFlexProperties,
}
