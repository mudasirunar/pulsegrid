import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/services/sync_queue_manager.dart';
import 'sync_event.dart';
import 'sync_state.dart';

class SyncBloc extends Bloc<SyncEvent, SyncState> {
  final SyncQueueManager syncQueueManager;
  StreamSubscription<SyncQueueMetrics>? _metricsSubscription;

  SyncBloc({required this.syncQueueManager}) : super(const SyncState()) {
    on<SyncStarted>(_onSyncStarted);
    on<TriggerSyncEvent>(_onTriggerSync);
    on<RetryFailedSyncEvent>(_onRetryFailedSync);
    on<SyncMetricsUpdatedEvent>(_onSyncMetricsUpdated);

    _metricsSubscription = syncQueueManager.metricsStream.listen((metrics) {
      add(SyncMetricsUpdatedEvent(metrics));
    });
  }

  Future<void> _onSyncStarted(SyncStarted event, Emitter<SyncState> emit) async {
    final metrics = await syncQueueManager.getMetrics();
    emit(state.copyWith(
      status: metrics.overallStatus,
      pendingCount: metrics.pendingCount,
      failedCount: metrics.failedCount,
      isSyncing: metrics.isSyncing,
      lastSyncedAt: metrics.lastSyncedAt,
    ));
  }

  Future<void> _onTriggerSync(TriggerSyncEvent event, Emitter<SyncState> emit) async {
    await syncQueueManager.processQueue(force: event.force);
  }

  Future<void> _onRetryFailedSync(RetryFailedSyncEvent event, Emitter<SyncState> emit) async {
    await syncQueueManager.retryFailedOperations();
  }

  void _onSyncMetricsUpdated(SyncMetricsUpdatedEvent event, Emitter<SyncState> emit) {
    emit(state.copyWith(
      status: event.metrics.overallStatus,
      pendingCount: event.metrics.pendingCount,
      failedCount: event.metrics.failedCount,
      isSyncing: event.metrics.isSyncing,
      lastSyncedAt: event.metrics.lastSyncedAt,
    ));
  }

  @override
  Future<void> close() {
    _metricsSubscription?.cancel();
    return super.close();
  }
}

