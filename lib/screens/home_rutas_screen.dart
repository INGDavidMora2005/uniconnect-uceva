import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../models/route_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/route_service.dart';
import '../widgets/route_card.dart';
import '../widgets/bottom_nav_bar.dart';
import 'profile_screen.dart';
import 'publicar_ruta_screen.dart';
import 'notifications_screen.dart';

class HomeRutasScreen extends StatefulWidget {
  const HomeRutasScreen({super.key});

  @override
  State<HomeRutasScreen> createState() => _HomeRutasScreenState();
}

class _HomeRutasScreenState extends State<HomeRutasScreen> {
  int _currentNavIndex = 0;
  int _selectedFilter = 0;
  final TextEditingController _searchController = TextEditingController();
  UserModel? _user;

  final List<String> _filters = ['Todas', 'Mañana', 'Tarde', 'Noche'];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await AuthService().getUserData();
    setState(() => _user = user);
  }

  String get _firstName {
    if (_user == null) return '...';
    return _user!.fullName.trim().split(' ').first;
  }

  String get _initials {
    if (_user == null) return '?';
    final parts = _user!.fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  List<RouteModel> _applyFilters(List<RouteModel> routes) {
    String query = _searchController.text.toLowerCase();
    return routes.where((r) {
      bool matchesSearch = query.isEmpty ||
          r.origin.toLowerCase().contains(query) ||
          r.destination.toLowerCase().contains(query);
      if (!matchesSearch) return false;
      if (_selectedFilter == 0) return true;
      final timeParts = r.time.split(':');
      int hour = int.tryParse(timeParts[0]) ?? 0;
      final isPM = r.time.toUpperCase().contains('PM');
      if (isPM && hour != 12) hour += 12;
      if (!isPM && hour == 12) hour = 0;
      if (_selectedFilter == 1) return hour >= 5 && hour < 12;
      if (_selectedFilter == 2) return hour >= 12 && hour < 18;
      if (_selectedFilter == 3) return hour >= 18 || hour < 5;
      return true;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildRutasContent() {
    return Column(
      children: [
        // ── Header ──────────────────────────────────────────
        Container(
          color: AppColors.backgroundWhite,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hola, $_firstName 👋',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const Text(
                    '¿A dónde vas hoy?',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => setState(() => _currentNavIndex = 3),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.accentGreen,
                  child: Text(
                    _initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Contenido scrolleable ────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Barra de búsqueda
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Buscar rutas disponibles...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.textPlaceholder,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: AppColors.textPlaceholder,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),

                // Filtros
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(_filters.length, (i) {
                      final selected = _selectedFilter == i;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedFilter = i),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.accentGreen
                                : AppColors.backgroundWhite,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? AppColors.accentGreen
                                  : AppColors.borderDefault,
                            ),
                          ),
                          child: Text(
                            _filters[i],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: selected
                                  ? Colors.white
                                  : AppColors.textMedium,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Mis rutas (solo si es conductor) ────────
                StreamBuilder<List<RouteModel>>(
                  stream: RouteService().getAvailableRoutes(),
                  builder: (context, snapshot) {
                    final allRoutes = snapshot.data ?? [];
                    final myRoutes = allRoutes
                        .where((r) => r.driverId == _currentUid)
                        .toList();

                    if (myRoutes.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Mis rutas',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            TextButton(
                              onPressed: () {},
                              child: const Text(
                                'Ver todas',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.accentGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: myRoutes.length,
                          itemBuilder: (_, i) => RouteCard(
                            route: myRoutes[i],
                            onTap: () {},
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    );
                  },
                ),

                // ── Título Rutas disponibles + Ver todas ────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Rutas disponibles',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text(
                        'Ver todas',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.accentGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ── Lista rutas disponibles (de otros) ──────
                StreamBuilder<List<RouteModel>>(
                  stream: RouteService().getAvailableRoutes(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: CircularProgressIndicator(
                            color: AppColors.accentGreen,
                          ),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Colors.redAccent, size: 40),
                              const SizedBox(height: 8),
                              Text(
                                'Error: ${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final allRoutes = snapshot.data ?? [];
                    // Rutas de otros conductores activas (excluye las propias)
                    final otherRoutes = allRoutes
                        .where((r) =>
                            r.driverId != _currentUid &&
                            r.status == 'Activa')
                        .toList();
                    final filtered = _applyFilters(otherRoutes);

                    if (filtered.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              Icon(
                                Icons.directions_car_outlined,
                                size: 48,
                                color: AppColors.borderDefault,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No hay rutas disponibles',
                                style: TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '¡Sé el primero en publicar una!',
                                style: TextStyle(
                                  color: AppColors.textPlaceholder,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => RouteCard(
                        route: filtered[i],
                        onTap: () {
                          // TODO: abrir detalle de ruta con opción de reservar cupo
                        },
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Botón Publicar Ruta
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PublicarRutaScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      'Publicar Ruta',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      body: SafeArea(
        child: IndexedStack(
          index: _currentNavIndex,
          children: [
            _buildRutasContent(),
            const Center(child: Text('Bazar - Próximamente')),
            const NotificationsScreen(),
            const ProfileScreen(showBottomNav: false),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentNavIndex,
        onTap: (i) => setState(() => _currentNavIndex = i),
      ),
    );
  }
}