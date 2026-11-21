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
}
