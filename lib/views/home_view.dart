import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodel/home_viewmodel.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HomeViewmodel(),
      child: const _HomeScreen(),
    );
  }
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HomeViewmodel>();

    return Scaffold(
      body: controller.pages[controller.selectedIndex],
      bottomNavigationBar: Container(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GNav(
              backgroundColor: const Color(0xFFF8F9FF),
              color: const Color(0xFF5D4B8A),
              activeColor: const Color(0xFF5D4B8A),
              tabBackgroundColor: Colors.transparent,
              gap: 4,
              iconSize: 24,
              padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 20),
              tabs: const [
                GButton(icon: Icons.home_outlined),
                GButton(icon: Icons.add),
                GButton(icon: Icons.calendar_month),
              ],
              selectedIndex: controller.selectedIndex,
              onTabChange: controller.onItemTapped,
            ),
          ),
        ),
      ),
    );
  }
}
