import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/resource_repository.dart';
import 'resource_state.dart';

class ResourceCubit extends Cubit<ResourceState> {
  final ResourceRepository resourceRepository;

  ResourceCubit({required this.resourceRepository}) : super(const ResourceInitial());

  /// Loads aggregated summary and full logs for the incident
  Future<void> loadResources(String incidentId) async {
    emit(const ResourceLoading());
    try {
      final summary = await resourceRepository.getResourceSummary(incidentId);
      final logs = await resourceRepository.getResourceLogs(incidentId);
      emit(ResourceLoaded(summary: summary, logs: logs));
    } catch (e) {
      emit(ResourceError(message: e.toString()));
    }
  }

  /// Logs a new resource entry and refreshes data
  Future<bool> logResource({
    required String incidentId,
    required String resourceType,
    required double quantity,
    required String unit,
    String? notes,
    required String loggedBy,
  }) async {
    final currentSummary = state is ResourceLoaded
        ? (state as ResourceLoaded).summary
        : state is ResourceOperationSuccess
            ? (state as ResourceOperationSuccess).summary
            : state is ResourceLoggingInProgress
                ? (state as ResourceLoggingInProgress).currentSummary
                : const [];
    final currentLogs = state is ResourceLoaded
        ? (state as ResourceLoaded).logs
        : state is ResourceOperationSuccess
            ? (state as ResourceOperationSuccess).logs
            : state is ResourceLoggingInProgress
                ? (state as ResourceLoggingInProgress).currentLogs
                : const [];

    emit(ResourceLoggingInProgress(
      currentSummary: currentSummary.cast(),
      currentLogs: currentLogs.cast(),
    ));

    try {
      final loggedEntity = await resourceRepository.logResource(
        incidentId: incidentId,
        resourceType: resourceType,
        quantity: quantity,
        unit: unit,
        notes: notes,
        loggedBy: loggedBy,
      );

      // Re-fetch updated summary and logs
      final updatedSummary = await resourceRepository.getResourceSummary(incidentId);
      final updatedLogs = await resourceRepository.getResourceLogs(incidentId);

      final formattedQty = quantity.truncateToDouble() == quantity
          ? quantity.toInt().toString()
          : quantity.toStringAsFixed(1);
      final successMsg = 'Logged $formattedQty $unit of $resourceType';

      emit(ResourceOperationSuccess(
        message: successMsg,
        loggedResource: loggedEntity,
        summary: updatedSummary,
        logs: updatedLogs,
      ));
      return true;
    } catch (e) {
      emit(ResourceError(
        message: e.toString().replaceAll('Exception: ', '').replaceAll('[VALIDATION_ERROR] ', ''),
        previousSummary: currentSummary.cast(),
        previousLogs: currentLogs.cast(),
      ));
      return false;
    }
  }
}

