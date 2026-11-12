import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/network_info.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_image_viewer.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../injection_container.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/entities/incident_severity.dart';
import '../../domain/services/location_service.dart';
import '../../domain/services/media_service.dart';
import '../bloc/incident_bloc.dart';
import '../bloc/incident_event.dart';
import '../bloc/incident_state.dart';

class CreateIncidentScreen extends StatefulWidget {
  final UserEntity currentUser;
  final LocationService? locationService;
  final MediaService? mediaService;
  final NetworkInfo? networkInfo;

  const CreateIncidentScreen({
    super.key,
    required this.currentUser,
    this.locationService,
    this.mediaService,
    this.networkInfo,
  });

  @override
  State<CreateIncidentScreen> createState() => _CreateIncidentScreenState();
}

class _FallbackNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(true);
}

class _CreateIncidentScreenState extends State<CreateIncidentScreen> {
  late final LocationService _locationService;
  late final MediaService _mediaService;
  late final NetworkInfo _networkInfo;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationNotesController = TextEditingController();
  final _customCategoryController = TextEditingController();

  String _selectedCategory = 'Medical';
  IncidentSeverity _selectedSeverity = IncidentSeverity.high;

  double? _latitude;
  double? _longitude;
  bool _isCapturingLocation = false;
  bool _isResolvingAddress = false;
  String? _detectedAddress;
  bool _showAddressSuggestion = false;
  Timer? _detectingTimer;
  final List<String> _photoPaths = [];
  static const int maxPhotos = 5;

  String? _titleError;
  String? _descriptionError;

  static const List<String> _categories = [
    'Medical',
    'Fire',
    'Hazmat',
    'Structural Collapse',
    'Search & Rescue',
    'Infrastructure',
    'Evacuation',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _locationService = widget.locationService ?? LocationServiceImpl();
    _mediaService = widget.mediaService ?? MediaServiceImpl();
    _networkInfo = widget.networkInfo ??
        (sl.isRegistered<NetworkInfo>()
            ? sl<NetworkInfo>()
            : _FallbackNetworkInfo());
  }

  @override
  void dispose() {
    _detectingTimer?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _locationNotesController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  Future<void> _captureLocation() async {
    _detectingTimer?.cancel();
    setState(() {
      _isCapturingLocation = true;
      _isResolvingAddress = false;
      _showAddressSuggestion = false;
      _detectedAddress = null;
    });

    final canShowRationaleBefore =
        await _locationService.shouldShowLocationRationale();
    if (!mounted) return;

    final currentStatus = await _locationService.checkPermissionStatus();
    if (!mounted) return;

    if (currentStatus == LocationPermissionStatus.permanentlyDenied) {
      setState(() => _isCapturingLocation = false);
      _showPermissionDialog(
        title: 'Location Permission',
        message:
            'Location access was denied. PulseGrid needs location permission to attach GPS coordinates to emergency incident reports. Please enable it in App Settings.',
        icon: Icons.location_on_outlined,
        onOpenSettings: () => _locationService.openAppSettings(),
      );
      return;
    }

    final permStatus = await _locationService.requestPermissionStatus();
    if (!mounted) return;

    if (permStatus == LocationPermissionStatus.granted) {
      // Proceed to coords lock below
    } else if (Platform.isAndroid &&
        permStatus == LocationPermissionStatus.permanentlyDenied &&
        !canShowRationaleBefore) {
      setState(() => _isCapturingLocation = false);
      _showPermissionDialog(
        title: 'Location Permission',
        message:
            'Location access was denied. PulseGrid needs location permission to attach GPS coordinates to emergency incident reports. Please enable it in App Settings.',
        icon: Icons.location_on_outlined,
        onOpenSettings: () => _locationService.openAppSettings(),
      );
      return;
    } else {
      setState(() => _isCapturingLocation = false);
      AppSnackBar.showWarning(
        context,
        'Location permission is required to capture GPS coordinates.',
        title: 'Permission Denied',
      );
      return;
    }

    final coords = await _locationService.getCurrentLocation();
    if (!mounted) return;

    if (coords != null) {
      // Phase 1: INSTANT SATELLITE LOCK (<300ms) - display coordinates immediately!
      setState(() {
        _latitude = coords.latitude;
        _longitude = coords.longitude;
        _isCapturingLocation = false;
      });

      // Phase 2: Check internet connection BEFORE geocoding
      final isOnline = await _networkInfo.isConnected;
      if (!isOnline || !mounted) {
        // Offline: Do NOT trigger geocoding or show transient detecting badge.
        return;
      }

      // Online: Delay showing "Detecting address..." by 300ms.
      // If the lookup finishes or fails faster than 300ms, the badge NEVER shows.
      // This completely eliminates any 1-frame or split-second flicker!
      _detectingTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() => _isResolvingAddress = true);
        }
      });

      try {
        final address = await _locationService.reverseGeocode(
          latitude: coords.latitude,
          longitude: coords.longitude,
        );
        _detectingTimer?.cancel();
        if (!mounted) return;

        if (address != null && address.isNotEmpty) {
          setState(() {
            _isResolvingAddress = false;
            final currentText = _locationNotesController.text.trim();
            if (currentText.isEmpty) {
              // Stage 2A: Field is empty -> auto-fill smoothly
              _locationNotesController.text = address;
            } else if (currentText != address) {
              // Stage 2B: User already typed custom text -> show smart suggestion pill
              _detectedAddress = address;
              _showAddressSuggestion = true;
            }
          });
        } else {
          if (mounted) setState(() => _isResolvingAddress = false);
        }
      } catch (_) {
        _detectingTimer?.cancel();
        if (mounted) setState(() => _isResolvingAddress = false);
      }
    } else {
      _detectingTimer?.cancel();
      setState(() {
        _isCapturingLocation = false;
        _isResolvingAddress = false;
      });
      AppSnackBar.showWarning(
        context,
        'GPS signal unavailable or permission denied. Please enter manual location details below.',
        title: 'Location Notice',
      );
    }
  }

  Future<void> _pickPhoto(bool fromCamera) async {
    if (_photoPaths.length >= maxPhotos) {
      AppSnackBar.showWarning(
        context,
        'Maximum of 5 evidence photos allowed per incident.',
        title: 'Photo Limit Reached',
      );
      return;
    }

    if (fromCamera) {
      final canShowRationaleBefore =
          await _mediaService.shouldShowCameraRationale();
      if (!mounted) return;

      final currentStatus = await _mediaService.checkCameraPermission();
      if (!mounted) return;

      if (currentStatus == MediaPermissionStatus.permanentlyDenied) {
        _showPermissionDialog(
          title: 'Camera Permission',
          message:
              'Camera access was denied. PulseGrid needs camera permission to capture live incident photos. Please enable it in App Settings.',
          icon: Icons.camera_alt_outlined,
        );
        return;
      }

      final status = await _mediaService.requestCameraPermission();
      if (!mounted) return;

      if (status == MediaPermissionStatus.granted) {
        final path = await _mediaService.pickImageFromCamera();
        if (!mounted) return;
        if (path != null) {
          setState(() => _photoPaths.add(path));
        }
      } else if (Platform.isAndroid &&
          status == MediaPermissionStatus.permanentlyDenied &&
          !canShowRationaleBefore) {
        _showPermissionDialog(
          title: 'Camera Permission',
          message:
              'Camera access was denied. PulseGrid needs camera permission to capture live incident photos. Please enable it in App Settings.',
          icon: Icons.camera_alt_outlined,
        );
      } else {
        AppSnackBar.showWarning(
          context,
          'Camera permission is required to capture evidence photos.',
          title: 'Permission Denied',
        );
      }
    } else {
      final canShowRationaleBefore =
          await _mediaService.shouldShowGalleryRationale();
      if (!mounted) return;

      final currentStatus = await _mediaService.checkGalleryPermission();
      if (!mounted) return;

      if (currentStatus == MediaPermissionStatus.permanentlyDenied) {
        _showPermissionDialog(
          title: 'Photo Library Permission',
          message:
              'Photo Library access was denied. PulseGrid needs photo library permission to select incident photos. Please enable it in App Settings.',
          icon: Icons.photo_library_outlined,
        );
        return;
      }

      final status = await _mediaService.requestGalleryPermission();
      if (!mounted) return;

      if (status == MediaPermissionStatus.granted) {
        final remaining = maxPhotos - _photoPaths.length;
        final picked = await _mediaService.pickMultipleImagesFromGallery(
          maxImages: remaining,
        );
        if (!mounted) return;
        if (picked.isNotEmpty) {
          setState(() {
            for (final p in picked) {
              if (_photoPaths.length < maxPhotos && !_photoPaths.contains(p)) {
                _photoPaths.add(p);
              }
            }
          });
        }
      } else if (Platform.isAndroid &&
          status == MediaPermissionStatus.permanentlyDenied &&
          !canShowRationaleBefore) {
        _showPermissionDialog(
          title: 'Photo Library Permission',
          message:
              'Photo Library access was denied. PulseGrid needs photo library permission to select incident photos. Please enable it in App Settings.',
          icon: Icons.photo_library_outlined,
        );
      } else {
        AppSnackBar.showWarning(
          context,
          'Photo library permission is required to attach images.',
          title: 'Permission Denied',
        );
      }
    }
  }

  void _showPermissionDialog({
    required String title,
    required String message,
    required IconData icon,
    VoidCallback? onOpenSettings,
  }) {
    AppDialog.show<void>(
      context: context,
      title: title,
      message: message,
      icon: icon,
      cancelText: 'Cancel',
      confirmText: 'Open Settings',
      onConfirm: onOpenSettings ?? () => _mediaService.openAppSettings(),
    );
  }

  void _removePhotoAt(int index) {
    setState(() {
      _photoPaths.removeAt(index);
    });
  }

  void _onSubmit() {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    String? tErr;
    String? dErr;

    if (title.isEmpty) {
      tErr = 'Incident title is required';
    } else if (title.length < 4) {
      tErr = 'Title must be at least 4 characters';
    }

    if (description.isEmpty) {
      dErr = 'Operational description is required';
    } else if (description.length < 10) {
      dErr = 'Description must be at least 10 characters';
    }

    setState(() {
      _titleError = tErr;
      _descriptionError = dErr;
    });

    if (tErr == null && dErr == null) {
      final category =
          (_selectedCategory == 'Other' &&
              _customCategoryController.text.trim().isNotEmpty)
          ? _customCategoryController.text.trim()
          : _selectedCategory;

      context.read<IncidentBloc>().add(
        CreateIncidentEvent(
          title: title,
          category: category,
          severity: _selectedSeverity,
          description: description,
          latitude: _latitude,
          longitude: _longitude,
          manualLocationNotes: _locationNotesController.text.trim().isNotEmpty
              ? _locationNotesController.text.trim()
              : null,
          photoPaths: _photoPaths,
          creator: widget.currentUser,
        ),
      );
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Medical':
        return Icons.medical_services_outlined;
      case 'Fire':
        return Icons.local_fire_department_outlined;
      case 'Hazmat':
        return Icons.warning_amber_rounded;
      case 'Structural Collapse':
        return Icons.domain_disabled_outlined;
      case 'Search & Rescue':
        return Icons.person_search_outlined;
      case 'Infrastructure':
        return Icons.electrical_services_outlined;
      case 'Evacuation':
        return Icons.directions_run_outlined;
      case 'Other':
      default:
        return Icons.more_horiz_rounded;
    }
  }

  Widget _buildCategoryCircleItem({
    required String category,
    required bool isSelected,
    required bool isDark,
    required bool isSubmitting,
  }) {
    final activeBg = isDark ? AppColors.accentDark : AppColors.primaryLight;
    final activeFg = isDark ? AppColors.backgroundDark : Colors.white;
    final unselectedBg = isDark
        ? AppColors.surfaceDark
        : AppColors.surfaceLight;
    final unselectedBorder = isDark
        ? AppColors.borderDark
        : AppColors.borderLight;
    final unselectedFg = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isSubmitting
          ? null
          : () => setState(() => _selectedCategory = category),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Circular Icon Box (Instagram-story / quick-action style)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? activeBg : unselectedBg,
                border: Border.all(
                  color: isSelected ? activeBg : unselectedBorder,
                  width: isSelected ? 2.0 : 1.0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: activeBg.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Icon(
                  _categoryIcon(category),
                  size: 22,
                  color: isSelected ? activeFg : unselectedFg,
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Category Label Below with fixed height for perfect horizontal row baseline
            SizedBox(
              height: 28,
              child: Center(
                child: Text(
                  category,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.15,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? (isDark
                              ? AppColors.accentDark
                              : AppColors.primaryLight)
                        : (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCoordinates(double lat, double lng) {
    final latDir = lat >= 0 ? 'N' : 'S';
    final lngDir = lng >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(5)}° $latDir, ${lng.abs().toStringAsFixed(5)}° $lngDir';
  }

  Color _severityColor(IncidentSeverity s) => switch (s) {
    IncidentSeverity.critical => AppColors.severityCritical,
    IncidentSeverity.high => AppColors.severityHigh,
    IncidentSeverity.medium => AppColors.severityMedium,
    IncidentSeverity.low => AppColors.severityLow,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Report New Incident'), elevation: 0),
      body: BlocConsumer<IncidentBloc, IncidentState>(
        listener: (context, state) {
          if (state is IncidentCreatedSuccess) {
            AppSnackBar.showSuccess(
              context,
              'Incident "${state.incident.title}" recorded and queued for sync.',
              title: 'Incident Logged',
            );
            Navigator.of(context).pop();
          } else if (state is IncidentError) {
            AppSnackBar.showError(context, state.message);
          }
        },
        builder: (context, state) {
          final isSubmitting = state is IncidentCreating;
          final sectionHeadingStyle = theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          );
          final subHeadingStyle = theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 12.5,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Incident Title
                AppTextField(
                  controller: _titleController,
                  label: 'Incident Title',
                  hintText: 'e.g. Chemical Leak at Reactor 2',
                  prefixIcon: const Icon(Icons.campaign_outlined, size: 20),
                  borderRadius: 14.0,
                  minLines: 1,
                  maxLines: 3,
                  enabled: !isSubmitting,
                  errorText: _titleError,
                  onChanged: (val) {
                    if (_titleError != null) setState(() => _titleError = null);
                  },
                ),
                const SizedBox(height: 18),

                // 2. Category Selector
                Text('Category', style: sectionHeadingStyle),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final int columns = constraints.maxWidth < 320 ? 3 : 4;
                    final rows = <List<String>>[];
                    for (var i = 0; i < _categories.length; i += columns) {
                      final end = (i + columns < _categories.length)
                          ? i + columns
                          : _categories.length;
                      rows.add(_categories.sublist(i, end));
                    }

                    return Column(
                      children: [
                        for (int r = 0; r < rows.length; r++) ...[
                          if (r > 0) const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final cat in rows[r])
                                Expanded(
                                  child: _buildCategoryCircleItem(
                                    category: cat,
                                    isSelected: _selectedCategory == cat,
                                    isDark: isDark,
                                    isSubmitting: isSubmitting,
                                  ),
                                ),
                              // Fill any remaining slots in the last row to maintain uniform column width
                              for (int i = 0; i < columns - rows[r].length; i++)
                                const Expanded(child: SizedBox()),
                            ],
                          ),
                        ],
                      ],
                    );
                  },
                ),
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
                  child: _selectedCategory == 'Other'
                      ? Padding(
                          key: const ValueKey('custom_category_field'),
                          padding: const EdgeInsets.only(top: 14.0),
                          child: AppTextField(
                            controller: _customCategoryController,
                            label: 'Specify Category',
                            labelStyle: subHeadingStyle,
                            hintText: 'e.g. Wildlife Hazard, Flood',
                            prefixIcon: const Icon(
                              Icons.edit_outlined,
                              size: 20,
                            ),
                            borderRadius: 14.0,
                            minLines: 1,
                            maxLines: 3,
                            enabled: !isSubmitting,
                          ),
                        )
                      : const SizedBox.shrink(
                          key: ValueKey('custom_category_empty'),
                        ),
                ),
                const SizedBox(height: 20),

                // 3. Severity Level Selector
                Text('Severity Level', style: sectionHeadingStyle),
                const SizedBox(height: 8),
                Row(
                  children: IncidentSeverity.values.map((sev) {
                    final isSelected = _selectedSeverity == sev;
                    final color = _severityColor(sev);

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3.0),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: isSubmitting
                              ? null
                              : () => setState(() => _selectedSeverity = sev),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withValues(
                                      alpha: isDark ? 0.25 : 0.15,
                                    )
                                  : (isDark
                                        ? AppColors.surfaceDark
                                        : Colors.white),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? color
                                    : (isDark
                                          ? AppColors.borderDark
                                          : AppColors.borderLight),
                                width: isSelected ? 1.8 : 1.0,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              sev.value,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isSelected
                                    ? color
                                    : (isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // 4. Description
                AppTextField(
                  controller: _descriptionController,
                  label: 'Operational Description',
                  hintText: 'Detail observed hazards, casualties, access routes, and immediate risks...',
                  maxLines: 4,
                  minLines: 3,
                  borderRadius: 14.0,
                  enabled: !isSubmitting,
                  errorText: _descriptionError,
                  onChanged: (val) {
                    if (_descriptionError != null) {
                      setState(() => _descriptionError = null);
                    }
                  },
                ),
                const SizedBox(height: 24),

                // 5. Geolocation Telemetry (Flat Canvas)
                Text('GPS Coordinates', style: sectionHeadingStyle),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceDark
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _latitude != null
                            ? Icons.gps_fixed_rounded
                            : Icons.location_searching_rounded,
                        size: 20,
                        color: _latitude != null
                            ? AppColors.statusResolved
                            : (isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _latitude != null
                              ? _formatCoordinates(_latitude!, _longitude!)
                              : 'No GPS coordinates captured',
                          style: TextStyle(
                            fontWeight: _latitude != null
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontFamily: _latitude != null ? 'monospace' : null,
                            fontSize: 13,
                            color: _latitude != null
                                ? (isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight)
                                : (isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: Center(
                          child: _isCapturingLocation
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : IconButton(
                                  padding: EdgeInsets.zero,
                                  tooltip: _latitude != null
                                      ? 'Recapture GPS'
                                      : 'Capture GPS',
                                  icon: Icon(
                                    _latitude != null
                                        ? Icons.refresh_rounded
                                        : Icons.my_location_rounded,
                                    size: 20,
                                    color: isDark
                                        ? AppColors.accentDark
                                        : AppColors.primaryLight,
                                  ),
                                  onPressed: isSubmitting
                                      ? null
                                      : _captureLocation,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 6. Manual Location & Address
                Row(
                  children: [
                    Text('Location', style: subHeadingStyle),
                    if (_isResolvingAddress) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 11,
                        height: 11,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: isDark ? AppColors.accentDark : AppColors.primaryLight,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Detecting address...',
                        style: subHeadingStyle?.copyWith(
                          fontStyle: FontStyle.italic,
                          fontSize: 11.5,
                          color: isDark ? AppColors.accentDark : AppColors.primaryLight,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                AppTextField(
                  controller: _locationNotesController,
                  hintText: 'e.g. Sector 4, Building C, Room 302',
                  prefixIcon: const Icon(
                    Icons.edit_location_alt_outlined,
                    size: 20,
                  ),
                  borderRadius: 14.0,
                  minLines: 1,
                  maxLines: 5,
                  enabled: !isSubmitting,
                ),
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
                  child: (_showAddressSuggestion && _detectedAddress != null)
                      ? Padding(
                          key: const ValueKey('detected_address_suggestion'),
                          padding: const EdgeInsets.only(
                            top: 8.0,
                            left: 2.0,
                            right: 2.0,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  _detectedAddress!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.35,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.textPrimaryLight,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _locationNotesController.text =
                                        _detectedAddress!;
                                    _showAddressSuggestion = false;
                                  });
                                },
                                child: Text(
                                  'Use',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.accentDark
                                        : AppColors.primaryLight,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  setState(() {
                                    final current =
                                        _locationNotesController.text.trim();
                                    _locationNotesController.text =
                                        current.isEmpty
                                            ? _detectedAddress!
                                            : '$current, ${_detectedAddress!}';
                                    _showAddressSuggestion = false;
                                  });
                                },
                                child: Text(
                                  '+ Append',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.accentDark
                                        : AppColors.primaryLight,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () => setState(
                                    () => _showAddressSuggestion = false),
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(
                          key: ValueKey('detected_address_empty'),
                        ),
                ),
                const SizedBox(height: 24),

                // 6. Photo Attachment Section (Max 5)
                Text(
                  'Evidence Photos (${_photoPaths.length}/$maxPhotos)',
                  style: sectionHeadingStyle,
                ),
                const SizedBox(height: 8),

                if (_photoPaths.isNotEmpty) ...[
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _photoPaths.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final path = _photoPaths[index];
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            alignment: Alignment.topRight,
                            children: [
                              GestureDetector(
                                onTap: () => AppImageViewer.show(
                                  context,
                                  photoPaths: _photoPaths,
                                  initialIndex: index,
                                ),
                                child: Image.file(
                                  File(path),
                                  height: 120,
                                  width: 120,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        height: 120,
                                        width: 120,
                                        color: Colors.grey.withValues(alpha: 0.2),
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.broken_image,
                                          size: 28,
                                        ),
                                      ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: CircleAvatar(
                                  backgroundColor: Colors.black.withValues(
                                    alpha: 0.7,
                                  ),
                                  radius: 14,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    onPressed: isSubmitting
                                        ? null
                                        : () => _removePhotoAt(index),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 4,
                                left: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '#${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (_photoPaths.length < maxPhotos)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isSubmitting
                              ? null
                              : () => _pickPhoto(true),
                          icon: const Icon(Icons.camera_alt_outlined, size: 18),
                          label: Text(
                            _photoPaths.isEmpty ? 'Camera' : 'Add Camera',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isSubmitting
                              ? null
                              : () => _pickPhoto(false),
                          icon: const Icon(
                            Icons.photo_library_outlined,
                            size: 18,
                          ),
                          label: Text(
                            _photoPaths.isEmpty ? 'Gallery' : 'Add Gallery',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 32),

                // 7. Submit Action Button
                AppButton(
                  text: 'Report Incident',
                  isLoading: isSubmitting,
                  isDisabled: isSubmitting,
                  borderRadius: 14.0,
                  height: 50.0,
                  onPressed: isSubmitting ? null : _onSubmit,
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
