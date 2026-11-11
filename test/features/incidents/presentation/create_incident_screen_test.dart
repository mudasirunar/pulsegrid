import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsegrid/core/network/network_info.dart';
import 'package:pulsegrid/core/theme/app_theme.dart';
import 'package:pulsegrid/features/auth/domain/entities/user_entity.dart';
import 'package:pulsegrid/features/auth/domain/entities/user_role.dart';
import 'package:pulsegrid/features/incidents/domain/entities/activity_event_entity.dart';
import 'package:pulsegrid/features/incidents/domain/entities/incident_entity.dart';
import 'package:pulsegrid/features/incidents/domain/entities/incident_severity.dart';
import 'package:pulsegrid/features/incidents/domain/entities/incident_status.dart';
import 'package:pulsegrid/features/incidents/domain/repositories/incident_repository.dart';
import 'package:pulsegrid/features/incidents/domain/services/location_service.dart';
import 'package:pulsegrid/features/incidents/domain/services/media_service.dart';
import 'package:pulsegrid/features/incidents/presentation/bloc/incident_bloc.dart';
import 'package:pulsegrid/features/incidents/presentation/screens/create_incident_screen.dart';

class _FakeLocationService implements LocationService {
  final ({double latitude, double longitude})? coords;
  final String? address;
  LocationPermissionStatus permissionStatus;
  bool settingsOpened = false;

  _FakeLocationService([
    this.coords,
    this.address,
    this.permissionStatus = LocationPermissionStatus.granted,
  ]);

  @override
  Future<({double latitude, double longitude})?> getCurrentLocation() async => coords;

  @override
  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async => address;

  @override
  Future<bool> checkPermission() async =>
      permissionStatus == LocationPermissionStatus.granted;

  @override
  Future<bool> requestPermission() async =>
      permissionStatus == LocationPermissionStatus.granted;

  @override
  Future<LocationPermissionStatus> checkPermissionStatus() async =>
      permissionStatus;

  @override
  Future<LocationPermissionStatus> requestPermissionStatus() async =>
      permissionStatus;

  bool locationRationale = false;

  @override
  Future<bool> shouldShowLocationRationale() async => locationRationale;

  @override
  Future<bool> openAppSettings() async {
    settingsOpened = true;
    return true;
  }
}

class _FakeNetworkInfo implements NetworkInfo {
  final bool connected;
  _FakeNetworkInfo([this.connected = true]);

  @override
  Future<bool> get isConnected async => connected;

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(connected);
}

class _FakeMediaService implements MediaService {
  final List<String> cameraReturnPaths;
  final List<String> galleryReturnPaths;
  MediaPermissionStatus cameraPermission;
  MediaPermissionStatus galleryPermission;
  bool settingsOpened = false;
  int _cameraIndex = 0;

  _FakeMediaService({
    this.cameraReturnPaths = const [],
    this.galleryReturnPaths = const [],
    this.cameraPermission = MediaPermissionStatus.granted,
    this.galleryPermission = MediaPermissionStatus.granted,
  });

  @override
  Future<MediaPermissionStatus> checkCameraPermission() async =>
      cameraPermission;

  @override
  Future<MediaPermissionStatus> requestCameraPermission() async =>
      cameraPermission;

  @override
  Future<MediaPermissionStatus> checkGalleryPermission() async =>
      galleryPermission;

  @override
  Future<MediaPermissionStatus> requestGalleryPermission() async =>
      galleryPermission;

  bool cameraRationale = false;
  bool galleryRationale = false;

  @override
  Future<bool> shouldShowCameraRationale() async => cameraRationale;

  @override
  Future<bool> shouldShowGalleryRationale() async => galleryRationale;

  @override
  Future<bool> openAppSettings() async {
    settingsOpened = true;
    return true;
  }

  @override
  Future<String?> pickImageFromCamera() async {
    if (_cameraIndex < cameraReturnPaths.length) {
      return cameraReturnPaths[_cameraIndex++];
    }
    return null;
  }

  @override
  Future<String?> pickImageFromGallery() async =>
      galleryReturnPaths.isNotEmpty ? galleryReturnPaths.first : null;

  @override
  Future<List<String>> pickMultipleImagesFromGallery({int maxImages = 5}) async =>
      galleryReturnPaths.take(maxImages).toList();
}

class _MockRepo implements IncidentRepository {
  IncidentEntity? lastCreated;

  @override
  Future<IncidentEntity> createIncident(IncidentEntity incident) async {
    lastCreated = incident;
    return incident;
  }

  @override
  Future<List<IncidentEntity>> getIncidents({
    IncidentStatus? statusFilter,
    IncidentSeverity? severityFilter,
    String? searchQuery,
  }) async => [];

  @override
  Future<IncidentEntity?> getIncidentById(String id) async => null;

  @override
  Future<IncidentEntity> updateIncidentStatus({
    required String incidentId,
    required IncidentStatus targetStatus,
    required UserEntity actor,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<ActivityEventEntity>> getActivityTimeline(String incidentId) async => [];
}

void main() {
  late _MockRepo repository;
  late IncidentBloc bloc;

  final user = const UserEntity(
    id: 'user_responder_1',
    email: 'responder@pulsegrid.com',
    displayName: 'Paramedic Jane',
    role: UserRole.responder,
  );

  setUp(() {
    repository = _MockRepo();
    bloc = IncidentBloc(incidentRepository: repository);
  });

  tearDown(() => bloc.close());

  Widget buildScreen({
    LocationService? locationService,
    MediaService? mediaService,
    NetworkInfo? networkInfo,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: BlocProvider<IncidentBloc>.value(
        value: bloc,
        child: CreateIncidentScreen(
          currentUser: user,
          locationService: locationService ??
              _FakeLocationService(
                (latitude: 37.7749, longitude: -122.4194),
              ),
          mediaService: mediaService ?? _FakeMediaService(),
          networkInfo: networkInfo ?? _FakeNetworkInfo(true),
        ),
      ),
    );
  }

  testWidgets('Validation: shows error on empty title & description and clears on typing',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // Verify form renders
    expect(find.text('Report New Incident'), findsOneWidget);
    expect(find.text('Report Incident'), findsOneWidget);

    // Tap submit with empty fields
    await tester.tap(find.text('Report Incident'));
    await tester.pump();

    // Error text shown
    expect(find.text('Incident title is required'), findsOneWidget);
    expect(find.text('Operational description is required'), findsOneWidget);

    // Type in title -> error clears
    await tester.enterText(find.byType(TextField).first, 'Transformer Explosion');
    await tester.pump();

    expect(find.text('Incident title is required'), findsNothing);
    expect(find.text('Operational description is required'), findsOneWidget);
  });

  testWidgets('GPS capture: fetches coordinates and fills location display with reverse-geocoded address',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final fakeLocation = _FakeLocationService(
      (latitude: 40.7128, longitude: -74.0060),
      'Broadway & 42nd St, Manhattan, NY',
    );

    await tester.pumpWidget(buildScreen(locationService: fakeLocation));
    await tester.pumpAndSettle();

    // Tap "Capture GPS"
    await tester.tap(find.byTooltip('Capture GPS'));
    await tester.pumpAndSettle();

    expect(find.text('40.71280° N, 74.00600° W'), findsOneWidget);
    expect(find.text('Broadway & 42nd St, Manhattan, NY'), findsOneWidget); // in location note field
  });

  testWidgets('GPS capture: if user already typed location, displays suggestion pill with Use and + Append',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final fakeLocation = _FakeLocationService(
      (latitude: 40.7128, longitude: -74.0060),
      'Broadway & 42nd St, Manhattan, NY',
    );

    await tester.pumpWidget(buildScreen(locationService: fakeLocation));
    await tester.pumpAndSettle();

    // Type in Location field before capturing GPS
    await tester.enterText(
      find.byWidgetPredicate((w) =>
          w is TextField &&
          w.decoration?.hintText == 'e.g. Sector 4, Building C, Room 302'),
      'Room 302, Sector 4',
    );
    await tester.pump();

    // Tap "Capture GPS"
    await tester.tap(find.byTooltip('Capture GPS'));
    await tester.pumpAndSettle();

    // Coordinates locked
    expect(find.text('40.71280° N, 74.00600° W'), findsOneWidget);
    // User typed text is NOT overwritten
    expect(find.text('Room 302, Sector 4'), findsOneWidget);
    // Suggestion displayed flat without card or prefix
    expect(find.text('Broadway & 42nd St, Manhattan, NY'), findsOneWidget);
    expect(find.text('Use'), findsOneWidget);
    expect(find.text('+ Append'), findsOneWidget);

    // Tap + Append
    await tester.tap(find.text('+ Append'));
    await tester.pumpAndSettle();

    // Combines user text + detected address
    expect(find.text('Room 302, Sector 4, Broadway & 42nd St, Manhattan, NY'),
        findsOneWidget);
    // Suggestion pill dismissed
    expect(find.text('+ Append'), findsNothing);
  });

  testWidgets(
      'GPS capture: when offline, captures coordinates instantly without flickering detecting badge or geocoding',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final fakeLocation = _FakeLocationService(
      (latitude: 40.7128, longitude: -74.0060),
      'Should Not Be Called',
    );

    await tester.pumpWidget(buildScreen(
      locationService: fakeLocation,
      networkInfo: _FakeNetworkInfo(false), // OFFLINE
    ));
    await tester.pumpAndSettle();

    // Tap "Capture GPS"
    await tester.tap(find.byTooltip('Capture GPS'));
    await tester.pump();

    // Coordinates locked immediately
    expect(find.text('40.71280° N, 74.00600° W'), findsOneWidget);
    // Detecting address was NEVER shown
    expect(find.text('Detecting address...'), findsNothing);
    // Location field remains empty for manual input
    expect(find.text('Should Not Be Called'), findsNothing);
  });

  testWidgets('Submitting valid form dispatches CreateIncidentEvent',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // Fill Title
    await tester.enterText(find.byType(TextField).at(0), 'Substation Fire');
    // Fill Description
    await tester.enterText(find.byType(TextField).at(1), 'Active fire threatening adjacent residential units');
    await tester.pump();

    // Tap Submit
    await tester.tap(find.text('Report Incident'));
    await tester.pump();

    expect(repository.lastCreated, isNotNull);
    expect(repository.lastCreated!.title, 'Substation Fire');
    expect(repository.lastCreated!.category, 'Medical');
    expect(repository.lastCreated!.status, IncidentStatus.newIncident);
  });

  testWidgets('Multi-photo: picks multiple photos from gallery, shows thumbnails, removes photo, and enforces max 5',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mediaService = _FakeMediaService(
      galleryReturnPaths: [
        '/tmp/photo1.jpg',
        '/tmp/photo2.jpg',
        '/tmp/photo3.jpg',
      ],
      cameraReturnPaths: [
        '/tmp/photo4.jpg',
        '/tmp/photo5.jpg',
        '/tmp/photo6_overflow.jpg',
      ],
    );

    await tester.pumpWidget(buildScreen(mediaService: mediaService));
    await tester.pumpAndSettle();

    expect(find.text('Evidence Photos (0/5)'), findsOneWidget);

    // Tap Gallery button
    await tester.tap(find.widgetWithText(OutlinedButton, 'Gallery'));
    await tester.pumpAndSettle();

    // 3 photos attached
    expect(find.text('Evidence Photos (3/5)'), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('#2'), findsOneWidget);
    expect(find.text('#3'), findsOneWidget);

    // Remove photo #2 (second close button)
    final closeButtons = find.byIcon(Icons.close);
    expect(closeButtons, findsNWidgets(3));
    await tester.tap(closeButtons.at(1));
    await tester.pumpAndSettle();

    // Now 2 photos remain
    expect(find.text('Evidence Photos (2/5)'), findsOneWidget);

    // Tap Add Camera twice to add 2 more
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add Camera'));
    await tester.pumpAndSettle();
    expect(find.text('Evidence Photos (3/5)'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Add Camera'));
    await tester.pumpAndSettle();
    expect(find.text('Evidence Photos (4/5)'), findsOneWidget);

    // Add another via Add Camera to reach 5
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add Camera'));
    await tester.pumpAndSettle();
    expect(find.text('Evidence Photos (5/5)'), findsOneWidget);
    // Buttons hidden when limit is reached
    expect(find.byType(OutlinedButton), findsNothing);

    // Fill title and description to submit
    await tester.enterText(find.byType(TextField).at(0), 'Hazmat Chemical Spill');
    await tester.enterText(find.byType(TextField).at(1), 'Corrosive chemical leak in loading dock.');
    await tester.pump();

    // Tap submit
    await tester.tap(find.text('Report Incident'));
    await tester.pump();

    expect(repository.lastCreated, isNotNull);
    expect(repository.lastCreated!.photoPaths.length, 5);
  });

  testWidgets(
      'Camera permission: when permanently denied, shows dialog directing to App Settings',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mediaService = _FakeMediaService(
      cameraPermission: CameraPermissionStatus.permanentlyDenied,
    );

    await tester.pumpWidget(buildScreen(mediaService: mediaService));
    await tester.pumpAndSettle();

    // Tap "Camera"
    await tester.tap(find.widgetWithText(OutlinedButton, 'Camera'));
    await tester.pumpAndSettle();

    // Dialog shown
    expect(find.text('Camera Permission'), findsOneWidget);
    expect(
      find.text(
          'Camera access was denied. PulseGrid needs camera permission to capture live incident photos. Please enable it in App Settings.'),
      findsOneWidget,
    );
    expect(find.text('Open Settings'), findsOneWidget);

    // Tap "Open Settings"
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();

    expect(mediaService.settingsOpened, isTrue);
    expect(find.text('Camera Permission'), findsNothing);
  });

  testWidgets(
      'Camera permission: when denied once, asks again and opens camera when granted',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mediaService = _FakeMediaService(
      cameraPermission: CameraPermissionStatus.denied,
      cameraReturnPaths: ['/tmp/allowed_camera.jpg'],
    );

    await tester.pumpWidget(buildScreen(mediaService: mediaService));
    await tester.pumpAndSettle();

    // First click: user denies it in OS dialog
    await tester.tap(find.widgetWithText(OutlinedButton, 'Camera'));
    await tester.pumpAndSettle();

    // Dialog is NOT shown right after first denial; warning SnackBar is shown
    expect(find.text('Camera Permission'), findsNothing);
    expect(
        find.text('Camera permission is required to capture evidence photos.'),
        findsOneWidget);

    // On next click user grants it
    mediaService.cameraPermission = CameraPermissionStatus.granted;

    // Tap "Camera" again
    await tester.tap(find.widgetWithText(OutlinedButton, 'Camera'));
    await tester.pumpAndSettle();

    // Photo captured successfully
    expect(find.text('Evidence Photos (1/5)'), findsOneWidget);
  });

  testWidgets(
      'Gallery permission: when permanently denied, shows dialog directing to App Settings',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mediaService = _FakeMediaService(
      galleryPermission: MediaPermissionStatus.permanentlyDenied,
    );

    await tester.pumpWidget(buildScreen(mediaService: mediaService));
    await tester.pumpAndSettle();

    // Tap "Gallery"
    await tester.tap(find.widgetWithText(OutlinedButton, 'Gallery'));
    await tester.pumpAndSettle();

    // Dialog shown
    expect(find.text('Photo Library Permission'), findsOneWidget);
    expect(
      find.text(
          'Photo Library access was denied. PulseGrid needs photo library permission to select incident photos. Please enable it in App Settings.'),
      findsOneWidget,
    );
    expect(find.text('Open Settings'), findsOneWidget);

    // Tap "Open Settings"
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();

    expect(mediaService.settingsOpened, isTrue);
    expect(find.text('Photo Library Permission'), findsNothing);
  });

  testWidgets(
      'Gallery permission: when denied once, asks again and picks photos when granted',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mediaService = _FakeMediaService(
      galleryPermission: MediaPermissionStatus.denied,
      galleryReturnPaths: ['/tmp/allowed_gallery1.jpg', '/tmp/allowed_gallery2.jpg'],
    );

    await tester.pumpWidget(buildScreen(mediaService: mediaService));
    await tester.pumpAndSettle();

    // First click: user denies it in OS dialog
    await tester.tap(find.widgetWithText(OutlinedButton, 'Gallery'));
    await tester.pumpAndSettle();

    // Dialog is NOT shown right after first denial; warning SnackBar is shown
    expect(find.text('Photo Library Permission'), findsNothing);
    expect(
        find.text('Photo library permission is required to attach images.'),
        findsOneWidget);

    // On next click user grants it
    mediaService.galleryPermission = MediaPermissionStatus.granted;

    // Tap "Gallery" again
    await tester.tap(find.widgetWithText(OutlinedButton, 'Gallery'));
    await tester.pumpAndSettle();

    // Photos selected successfully
    expect(find.text('Evidence Photos (2/5)'), findsOneWidget);
  });

  testWidgets(
      'Location permission: when permanently denied, shows dialog directing to App Settings',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final locationService = _FakeLocationService(
      null,
      null,
      LocationPermissionStatus.permanentlyDenied,
    );

    await tester.pumpWidget(buildScreen(locationService: locationService));
    await tester.pumpAndSettle();

    // Tap GPS button
    await tester.tap(find.byIcon(Icons.my_location_rounded));
    await tester.pumpAndSettle();

    // Dialog shown
    expect(find.text('Location Permission'), findsOneWidget);
    expect(
      find.text(
          'Location access was denied. PulseGrid needs location permission to attach GPS coordinates to emergency incident reports. Please enable it in App Settings.'),
      findsOneWidget,
    );
    expect(find.text('Open Settings'), findsOneWidget);

    // Tap "Open Settings"
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();

    expect(locationService.settingsOpened, isTrue);
    expect(find.text('Location Permission'), findsNothing);
  });

  testWidgets(
      'Location permission: when denied once, asks again and captures GPS when granted',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final locationService = _FakeLocationService(
      (latitude: 37.7749, longitude: -122.4194),
      'San Francisco, CA',
      LocationPermissionStatus.denied,
    );

    await tester.pumpWidget(buildScreen(locationService: locationService));
    await tester.pumpAndSettle();

    // First click: user denies it in OS dialog
    await tester.tap(find.byIcon(Icons.my_location_rounded));
    await tester.pumpAndSettle();

    // Dialog is NOT shown right after first denial; warning SnackBar is shown
    expect(find.text('Location Permission'), findsNothing);
    expect(
        find.text('Location permission is required to capture GPS coordinates.'),
        findsOneWidget);

    // On next click user grants it
    locationService.permissionStatus = LocationPermissionStatus.granted;

    // Tap GPS button again
    await tester.tap(find.byIcon(Icons.my_location_rounded));
    await tester.pumpAndSettle();

    // GPS captured successfully
    expect(find.textContaining('37.77490° N'), findsOneWidget);
  });

  testWidgets(
      'Camera permission UX: first denial shows SnackBar, subsequent click shows AppDialog',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mediaService = _FakeMediaService(
      cameraPermission: CameraPermissionStatus.denied,
    );

    await tester.pumpWidget(buildScreen(mediaService: mediaService));
    await tester.pumpAndSettle();

    // 1st click: user denies in OS prompt
    await tester.tap(find.widgetWithText(OutlinedButton, 'Camera'));
    await tester.pumpAndSettle();

    // Polite SnackBar shown, NO dialog
    expect(find.text('Camera Permission'), findsNothing);
    expect(
      find.text('Camera permission is required to capture evidence photos.'),
      findsOneWidget,
    );

    // Permission is now permanently denied
    mediaService.cameraPermission = CameraPermissionStatus.permanentlyDenied;

    // 2nd click: user clicks button again
    await tester.tap(find.widgetWithText(OutlinedButton, 'Camera'));
    await tester.pumpAndSettle();

    // AppDialog is now shown offering to Open Settings
    expect(find.text('Camera Permission'), findsOneWidget);
    expect(find.text('Open Settings'), findsOneWidget);
  });

  testWidgets(
      'Location permission UX: first denial shows SnackBar, subsequent click shows AppDialog',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final locationService = _FakeLocationService(
      null,
      null,
      LocationPermissionStatus.denied,
    );

    await tester.pumpWidget(buildScreen(locationService: locationService));
    await tester.pumpAndSettle();

    // 1st click: user denies in OS prompt
    await tester.tap(find.byIcon(Icons.my_location_rounded));
    await tester.pumpAndSettle();

    // Polite SnackBar shown, NO dialog
    expect(find.text('Location Permission'), findsNothing);
    expect(
      find.text('Location permission is required to capture GPS coordinates.'),
      findsOneWidget,
    );

    // Permission is now permanently denied
    locationService.permissionStatus = LocationPermissionStatus.permanentlyDenied;

    // 2nd click: user clicks button again
    await tester.tap(find.byIcon(Icons.my_location_rounded));
    await tester.pumpAndSettle();

    // AppDialog is now shown offering to Open Settings
    expect(find.text('Location Permission'), findsOneWidget);
    expect(find.text('Open Settings'), findsOneWidget);
  });
}
