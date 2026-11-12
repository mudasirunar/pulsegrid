import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../domain/entities/resource_log_entity.dart';
import '../cubit/resource_cubit.dart';

class LogResourceBottomSheet extends StatefulWidget {
  final String incidentId;
  final UserEntity currentUser;
  final VoidCallback? onResourceLogged;

  const LogResourceBottomSheet({
    super.key,
    required this.incidentId,
    required this.currentUser,
    this.onResourceLogged,
  });

  static Future<void> show(
    BuildContext context, {
    required String incidentId,
    required UserEntity currentUser,
    VoidCallback? onResourceLogged,
  }) {
    if (currentUser.role == UserRole.viewer) {
      return Future.value();
    }
    final cubit = context.read<ResourceCubit>();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: LogResourceBottomSheet(
          incidentId: incidentId,
          currentUser: currentUser,
          onResourceLogged: onResourceLogged,
        ),
      ),
    );
  }

  @override
  State<LogResourceBottomSheet> createState() => _LogResourceBottomSheetState();
}

class _LogResourceBottomSheetState extends State<LogResourceBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _customResourceController = TextEditingController();
  final _notesController = TextEditingController();

  late String _selectedType;
  late String _selectedUnit;
  bool _isSubmitting = false;

  String? _quantityError;
  String? _customResourceError;

  @override
  void initState() {
    super.initState();
    _selectedType = ResourceLogEntity.standardTypes.first;
    _selectedUnit = ResourceLogEntity.defaultUnits[_selectedType] ?? 'Units';
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _customResourceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onTypeChanged(String? newType) {
    if (newType == null) return;
    setState(() {
      _selectedType = newType;
      _customResourceError = null;
      // Auto-update recommended default unit
      _selectedUnit = ResourceLogEntity.defaultUnits[newType] ?? _selectedUnit;
    });
  }

  Future<void> _submit() async {
    String? qErr;
    String? cErr;

    final qClean = _quantityController.text.trim();
    if (qClean.isEmpty) {
      qErr = 'Enter quantity';
    } else {
      final numVal = double.tryParse(qClean);
      if (numVal == null || numVal <= 0) {
        qErr = 'Must be > 0';
      }
    }

    if (_selectedType == 'Other' && _customResourceController.text.trim().isEmpty) {
      cErr = 'Please specify resource name';
    }

    setState(() {
      _quantityError = qErr;
      _customResourceError = cErr;
    });

    if (qErr != null || cErr != null) return;

    final qty = double.parse(qClean);
    final resolvedType = _selectedType == 'Other'
        ? _customResourceController.text.trim()
        : _selectedType;

    setState(() => _isSubmitting = true);

    final success = await context.read<ResourceCubit>().logResource(
          incidentId: widget.incidentId,
          resourceType: resolvedType,
          quantity: qty,
          unit: _selectedUnit,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          loggedBy: widget.currentUser.id,
        );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop();
        AppSnackBar.showSuccess(
          context,
          'Logged ${_formatQty(qty)} $_selectedUnit of $resolvedType',
        );
        widget.onResourceLogged?.call();
      }
    }
  }

  String _formatQty(double qty) {
    return qty.truncateToDouble() == qty ? qty.toInt().toString() : qty.toStringAsFixed(1);
  }

  IconData _resourceIcon(String type) {
    switch (type) {
      case 'Water':
        return Icons.water_drop_outlined;
      case 'First Aid Kits':
        return Icons.medical_services_outlined;
      case 'Oxygen Tanks':
        return Icons.air_rounded;
      case 'Blankets':
        return Icons.bed_rounded;
      case 'Food Rations':
        return Icons.restaurant_rounded;
      case 'Fuel':
        return Icons.local_gas_station_rounded;
      case 'Medical Kits':
        return Icons.health_and_safety_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    if (widget.currentUser.role == UserRole.viewer) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: bottomInset + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.primaryDark.withValues(alpha: 0.15) : AppColors.primaryLight.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Log Emergency Resource',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Record allocated supplies for this incident',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 1. Resource Type Dropdown
              Text(
                'RESOURCE TYPE',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                items: ResourceLogEntity.standardTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Row(
                      children: [
                        Icon(_resourceIcon(type), size: 18),
                        const SizedBox(width: 10),
                        Text(type),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: _onTypeChanged,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

              // Animated Slide-In Field when 'Other' is selected
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                reverseDuration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return SizeTransition(
                    sizeFactor: animation,
                    alignment: Alignment.topCenter,
                    child: ClipRect(
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.0, -0.3),
                          end: Offset.zero,
                        ).animate(animation),
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      ),
                    ),
                  );
                },
                child: _selectedType == 'Other'
                    ? Padding(
                        key: const ValueKey('custom_resource_name_field'),
                        padding: const EdgeInsets.only(top: 14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SPECIFY RESOURCE NAME',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _customResourceController,
                              onChanged: (val) {
                                if (_customResourceError != null) {
                                  setState(() => _customResourceError = null);
                                }
                              },
                              decoration: InputDecoration(
                                hintText: 'e.g. Generators, Sandbags, Stretchers',
                                prefixIcon: const Icon(Icons.edit_outlined, size: 18),
                                errorText: _customResourceError,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(
                        key: ValueKey('custom_resource_name_empty'),
                      ),
              ),
              const SizedBox(height: 16),

              // 2. Quantity & Unit Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quantity Field
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'QUANTITY',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _quantityController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (val) {
                            if (_quantityError != null) {
                              setState(() => _quantityError = null);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'e.g. 50',
                            errorText: _quantityError,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Unit Selector Field
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'UNIT',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          key: ValueKey('unit_$_selectedType'),
                          initialValue: ResourceLogEntity.standardUnits.contains(_selectedUnit)
                              ? _selectedUnit
                              : ResourceLogEntity.standardUnits.first,
                          items: ResourceLogEntity.standardUnits.map((u) {
                            return DropdownMenuItem(
                              value: u,
                              child: Text(u),
                            );
                          }).toList(),
                          onChanged: (newUnit) {
                            if (newUnit != null) {
                              setState(() => _selectedUnit = newUnit);
                            }
                          },
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Notes
              Text(
                'DEPLOYMENT NOTES',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'e.g. Delivered to Staging Area Alpha by Medical Team',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),

              // 4. Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Log Resource',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
