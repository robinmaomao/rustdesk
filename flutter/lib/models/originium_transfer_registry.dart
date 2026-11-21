import 'file_model.dart';

/// Process-wide view over the file transfer jobs of every open session.
///
/// RustDesk keeps job state inside a per-session [JobController]. The shell
/// needs a global view for two reasons:
///
/// * a file transfer window that is closed while jobs are running has to keep
///   its session (and therefore the transfer) alive, and
/// * the main window reports progress while that window is hidden.
class OriginiumTransferRegistry {
  OriginiumTransferRegistry._();

  static final OriginiumTransferRegistry instance =
      OriginiumTransferRegistry._();

  final Set<JobController> _controllers = <JobController>{};

  void register(JobController controller) => _controllers.add(controller);

  void unregister(JobController controller) => _controllers.remove(controller);

  /// Every transfer job that has not reached a terminal state yet.
  List<JobProgress> get activeJobs => _controllers
      .expand((controller) => controller.jobTable)
      .where((job) =>
          job.type == JobType.transfer &&
          (job.state == JobState.inProgress || job.state == JobState.paused))
      .toList(growable: false);

  bool get hasActiveTransfers => activeJobs.isNotEmpty;

  int get activeCount => activeJobs.length;

  int get totalSize =>
      activeJobs.fold<int>(0, (sum, job) => sum + job.totalSize);

  int get finishedSize =>
      activeJobs.fold<int>(0, (sum, job) => sum + job.finishedSize);

  double get percent =>
      totalSize > 0 ? (finishedSize / totalSize).clamp(0.0, 1.0) : 0.0;

  String get percentText => '${(percent * 100).toStringAsFixed(0)}%';

  /// Combined throughput of the running jobs, in bytes per second.
  double get speedBytesPerSecond => activeJobs
      .where((job) => job.state == JobState.inProgress)
      .fold<double>(0, (sum, job) => sum + job.speed);

  /// Rough time left for the whole queue, or null when it cannot be estimated.
  Duration? get eta {
    final speed = speedBytesPerSecond;
    final remaining = totalSize - finishedSize;
    if (speed <= 0 || remaining <= 0) return null;
    final seconds = (remaining / speed).ceil();
    if (seconds <= 0) return null;
    return Duration(seconds: seconds);
  }

  /// Cancels every running job. Used by the background transfer strip, where
  /// the transfer window itself may be minimised.
  Future<void> cancelAll() async {
    for (final controller in _controllers.toList(growable: false)) {
      for (final job in controller.jobTable.toList(growable: false)) {
        if (job.type != JobType.transfer) continue;
        if (job.state != JobState.inProgress && job.state != JobState.paused) {
          continue;
        }
        await controller.cancelJob(job.id);
      }
    }
  }
}
