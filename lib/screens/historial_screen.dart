import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/historial_viajes_tab.dart';
import '../widgets/historial_bazar_tab.dart';

class HistorialScreen extends StatefulWidget {
  final String uid;

  const HistorialScreen({Key? key, required this.uid}) : super(key: key);

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        title: const Text(
          'Mi historial',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            TabBar(
              indicatorColor: AppColors.accentGreen,
              labelColor: AppColors.accentGreen,
              unselectedLabelColor: AppColors.textLight,
              indicatorWeight: 2.5,
              tabs: const [
                Tab(text: 'Mis viajes'),
                Tab(text: 'Mis transacciones'),
              ],
            ),
            const Divider(
              height: 1,
              color: AppColors.borderDefault,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: HistorialViajesTab(uid: widget.uid),
                  ),
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: HistorialBazarTab(uid: widget.uid),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}