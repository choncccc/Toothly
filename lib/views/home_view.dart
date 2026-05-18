import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:provider/provider.dart';

import '../viewmodel/home_viewmodel.dart';

const _bgColor = Color(0xFFF8F9FF);
const _primary = Color(0xFF5D4B8A);
const _purpleLight = Color(0xFFB191FF);
const _purpleDeep = Color(0xFF8F6BFF);
const _border = Color(0xFFE6E1F5);

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

    final pages = controller.pages;
    final index = pages.isEmpty
        ? 0
        : controller.selectedIndex.clamp(0, pages.length - 1);

    return Scaffold(
      backgroundColor: _bgColor,
      body: IndexedStack(
        index: index,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: _border, width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: GNav(
              backgroundColor: Colors.white,
              color: _primary,
              activeColor: Colors.white,
              tabBackgroundGradient: const LinearGradient(
                colors: [_purpleLight, _purpleDeep],
              ),
              gap: 8,
              iconSize: 22,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              duration: const Duration(milliseconds: 250),
              tabBorderRadius: 16,
              haptic: true,
              tabs: const [
                GButton(
                  icon: Icons.home_rounded,
                  text: 'Home',
                  textStyle: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                GButton(
                  icon: Icons.folder_open_rounded,
                  text: 'Create',
                  textStyle: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                GButton(
                  icon: Icons.checklist_rounded,
                  text: 'Clinical',
                  textStyle: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                GButton(
                  icon: Icons.event_rounded,
                  text: 'Schedule',
                  textStyle: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
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
