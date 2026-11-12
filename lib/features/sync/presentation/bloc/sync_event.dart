import 'package:equatable/equatable.dart';
import '../../domain/services/sync_queue_manager.dart';

abstract class SyncEvent extends Equatable {
  const SyncEvent();

  @override
  List<Object?> get props => [];
}

class SyncStarted extends SyncEvent {
  const SyncStarted();
}

class TriggerSyncEvent extends SyncEvent {
  final bool force;

  const TriggerSyncEvent({this.force = false});

  @override
  List<Object?> get props => [force];
}

class RetryFailedSyncEvent extends SyncEvent {
  const RetryFailedSyncEvent();
}

class SyncMetricsUpdatedEvent extends SyncEvent {
  final SyncQueueMetrics metrics;

  const SyncMetricsUpdatedEvent(this.metrics);

  @override
  List<Object?> get props => [metrics];
}

