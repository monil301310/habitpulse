/// How close two log updates must be for the "done wins" rule to apply.
const Duration logConflictWindow = Duration(seconds: 5);

/// Whether a remote row should overwrite the local row.
///
/// Normal rule: the newest `updated_at` wins. For logs inside
/// [logConflictWindow], a remote `done` beats a local non-done status, and a
/// local `done` is never replaced by a remote non-done status. This stops two
/// devices tapping Done at nearly the same moment from losing the completion.
bool shouldApplyRemote({
  required DateTime? localUpdatedAt,
  required DateTime remoteUpdatedAt,
  bool isLog = false,
  String? localStatus,
  String? remoteStatus,
}) {
  if (localUpdatedAt == null) return true;

  final remoteIsNewer = remoteUpdatedAt.isAfter(localUpdatedAt);
  final withinWindow =
      remoteUpdatedAt.difference(localUpdatedAt).abs() <= logConflictWindow;

  if (isLog && withinWindow) {
    final remoteDone = remoteStatus == 'done';
    final localDone = localStatus == 'done';
    if (remoteDone && !localDone) return true;
    if (localDone && !remoteDone) return false;
  }

  return remoteIsNewer;
}
