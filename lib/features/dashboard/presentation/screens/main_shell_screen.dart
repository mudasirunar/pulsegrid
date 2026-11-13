import 'package:flutter/material.dart';

import '../../../../core/widgets/floating_island_nav_bar.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../incidents/presentation/screens/create_incident_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import 'home_screen.dart';

/// Root authenticated shell hosting [HomeScreen] and [ProfileScreen]
/// with the two-part [FloatingIslandNavBar].
class MainShellScreen extends StatefulWidget {
  final UserModel user;

  const MainShellScreen({super.key, required this.user});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;
  final ScrollController _homeScrollController = ScrollController();

  @override
  void dispose() {
    _homeScrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (_currentIndex == 0 && _homeScrollController.hasClients) {
      _homeScrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              HomeScreen(
                user: widget.user,
                scrollController: _homeScrollController,
              ),
              ProfileScreen(user: widget.user),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingIslandNavBar(
              currentIndex: _currentIndex,
              showActionButton: !widget.user.role.isReadOnly,
              onTabSelected: (index) {
                setState(() => _currentIndex = index);
              },
              onTabReselected: _scrollToTop,
              onActionPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CreateIncidentScreen(currentUser: widget.user),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

