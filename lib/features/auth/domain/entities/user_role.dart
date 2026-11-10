enum UserRole {
  coordinator,
  responder,
  viewer;

  String get displayName {
    switch (this) {
      case UserRole.coordinator:
        return 'Coordinator';
      case UserRole.responder:
        return 'Responder';
      case UserRole.viewer:
        return 'Viewer';
    }
  }

  /// Coordinators can assign and close incidents
  bool get canAssignAndClose => this == UserRole.coordinator;

  /// Responders can update assigned incidents and log resources
  bool get canUpdateAssignedAndLogResources =>
      this == UserRole.coordinator || this == UserRole.responder;

  /// Viewers have strictly read-only access
  bool get isReadOnly => this == UserRole.viewer;

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'coordinator':
        return UserRole.coordinator;
      case 'responder':
        return UserRole.responder;
      case 'viewer':
      default:
        return UserRole.viewer;
    }
  }
}

