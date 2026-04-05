import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'bazar_screen.dart';
import 'calificar_screen.dart';

class HomeRutasScreen extends StatefulWidget {
  const HomeRutasScreen({super.key});

  @override
  State<HomeRutasScreen> createState() => _HomeRutasScreenState();
}

class _HomeRutasScreenState extends State<HomeRutasScreen> {
  int _currentNavIndex = 0;
  int _selectedFilter = 0;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  UserModel? _user;

  // IDs de rutas rechazadas para este pasajero
  Set<String> _rejectedRouteIds = {};

  final List<String> _filters = ['Todas', 'Mañana', 'Tarde', 'Noche'];

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadRejectedRoutes();
  }

  Future<void> _loadUser() async {
    final user = await AuthService().getUserData();
    if (mounted) setState(() => _user = user);
  }

  /// Carga los routeIds donde el pasajero fue rechazado
  Future<void> _loadRejectedRoutes() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('cupo_requests')
        .where('passengerId', isEqualTo: uid)
        .where('status', isEqualTo: 'rejected')
        .get();
    if (mounted) {
      setState(() {
        _rejectedRouteIds = snap.docs
            .map((d) => d.data()['routeId'] as String)
            .toSet();
      });
    }
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
    final originFilter = _originController.text.toLowerCase().trim();
    final destinationFilter = _destinationController.text.toLowerCase().trim();
    final timeFilter = _timeController.text.toLowerCase().trim();
    final query = _searchController.text.toLowerCase();

    return routes.where((r) {
      final matchesOrigin =
          originFilter.isEmpty || r.origin.toLowerCase().contains(originFilter);
      final matchesDestination =
          destinationFilter.isEmpty ||
          r.destination.toLowerCase().contains(destinationFilter);
      final matchesTime =
          timeFilter.isEmpty || r.time.toLowerCase().contains(timeFilter);
      final matchesSearch =
          query.isEmpty ||
          r.origin.toLowerCase().contains(query) ||
          r.destination.toLowerCase().contains(query);

      if (!matchesOrigin ||
          !matchesDestination ||
          !matchesTime ||
          !matchesSearch)
        return false;
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
    _originController.dispose();
    _destinationController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  RouteModel _routeFromNotifData(Map<String, dynamic> data) {
    return RouteModel(
      id: data['routeId'] ?? '',
      origin: data['origin'] ?? '',
      destination: data['destination'] ?? '',
      date: data['date'] ?? '',
      time: data['time'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      availableSeats: 0,
      totalSeats: (data['totalSeats'] ?? 4) as int,
      driverName: data['driverName'] ?? '',
      driverInitials: data['driverInitials'] ?? '',
      driverRating: (data['driverRating'] ?? 0.0).toDouble(),
      meetingPoint: data['meetingPoint'] ?? '',
      driverId: data['driverId'] ?? '',
      status: RouteStatus.finalizada,
    );
  }

  Widget _buildRutasContent() {
    return Column(
      children: [
        // ── Header ────────────────────────────────────────
        Container(
          color: AppColors.primaryGreen,
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
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    '¿A dónde vas hoy?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
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

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Buscador ──────────────────────────────
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
                const SizedBox(height: 12),

                // ── Filtros ───────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _originController,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textDark,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Origen',
                          prefixIcon: Icon(
                            Icons.location_on,
                            color: AppColors.textPlaceholder,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _destinationController,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textDark,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Destino',
                          prefixIcon: Icon(
                            Icons.flag,
                            color: AppColors.textPlaceholder,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _timeController,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textDark,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Hora (ej. 10:00 AM)',
                          prefixIcon: Icon(
                            Icons.access_time,
                            color: AppColors.textPlaceholder,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Chips de turno ────────────────────────
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

                // ── Mis rutas ─────────────────────────────
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
                          itemBuilder: (_, i) =>
                              RouteCard(route: myRoutes[i], onTap: () {}),
                        ),
                        const SizedBox(height: 20),
                      ],
                    );
                  },
                ),

                // ── Rutas disponibles ─────────────────────
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
                              const Icon(
                                Icons.error_outline,
                                color: Colors.redAccent,
                                size: 40,
                              ),
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

                    final otherRoutes = allRoutes.where((r) {
                      if (r.driverId == _currentUid) return false;
                      if (r.status != RouteStatus.activa &&
                          r.status != RouteStatus.disponible &&
                          r.status != RouteStatus.llena)
                        return false;
                      // Ocultar rutas donde el pasajero fue rechazado
                      if (_rejectedRouteIds.contains(r.id)) return false;
                      return true;
                    }).toList();

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
                                'No hay rutas disponibles para tu búsqueda',
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
                        onTap: () {},
                        //  Recargar rutas rechazadas al volver
                        onRefreshRejected: _loadRejectedRoutes,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // ── Botón publicar ruta ───────────────────
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
            const BazarScreen(),
            NotificationsScreen(
              onRateTrip: (data) {
                final route = _routeFromNotifData(data);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CalificarScreen(route: route),
                  ),
                );
              },
            ),
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
