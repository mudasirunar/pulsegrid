import 'package:equatable/equatable.dart';

import '../../domain/entities/resource_log_entity.dart';
import '../../domain/entities/resource_summary_item.dart';

abstract class ResourceState extends Equatable {
  const ResourceState();

  @override
  List<Object?> get props => [];
}

class ResourceInitial extends ResourceState {
  const ResourceInitial();
}

class ResourceLoading extends ResourceState {
  const ResourceLoading();
}

class ResourceLoaded extends ResourceState {
  final List<ResourceSummaryItem> summary;
  final List<ResourceLogEntity> logs;

  const ResourceLoaded({
    required this.summary,
    required this.logs,
  });

  @override
  List<Object?> get props => [summary, logs];
}

class ResourceLoggingInProgress extends ResourceState {
  final List<ResourceSummaryItem> currentSummary;
  final List<ResourceLogEntity> currentLogs;

  const ResourceLoggingInProgress({
    this.currentSummary = const [],
    this.currentLogs = const [],
  });

  @override
  List<Object?> get props => [currentSummary, currentLogs];
}

class ResourceOperationSuccess extends ResourceState {
  final String message;
  final ResourceLogEntity loggedResource;
  final List<ResourceSummaryItem> summary;
  final List<ResourceLogEntity> logs;

  const ResourceOperationSuccess({
    required this.message,
    required this.loggedResource,
    required this.summary,
    required this.logs,
  });

  @override
  List<Object?> get props => [message, loggedResource, summary, logs];
}

class ResourceError extends ResourceState {
  final String message;
  final List<ResourceSummaryItem> previousSummary;
  final List<ResourceLogEntity> previousLogs;

  const ResourceError({
    required this.message,
    this.previousSummary = const [],
    this.previousLogs = const [],
  });

  @override
  List<Object?> get props => [message, previousSummary, previousLogs];
}

