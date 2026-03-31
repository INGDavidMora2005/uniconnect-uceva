import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/route_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../widgets/route_card.dart';
import '../widgets/bottom_nav_bar.dart';
import 'profile_screen.dart';

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

  final List<RouteModel> _routes = [
    RouteModel(
      id: '1',
      origin: 'Tuluá Centro',
      destination: 'UCEVA',
      date: 'Hoy',
      time: '7:00 AM',
      price: 3000,
      availableSeats: 2,
      totalSeats: 4,
      driverName: 'David M.',
      driverInitials: 'DM',
      driverRating: 4.8,
      meetingPoint: 'Parque Boyacá',
    ),
    RouteModel(
      id: '2',
      origin: 'Buga',
      destination: 'UCEVA',
      date: 'Hoy',
      time: '7:30 AM',
      price: 4000,
      availableSeats: 3,
      totalSeats: 4,
      driverName: 'Juan Pablo D.',
      driverInitials: 'JP',
      driverRating: 4.6,
      meetingPoint: 'Parque Boyacá',
    ),
    RouteModel(
      id: '3',
      origin: 'Andalucía',
      destination: 'UCEVA',
      date: 'Hoy',
      time: '8:30 AM',
      price: 4000,
      availableSeats: 0,
      totalSeats: 4,
      driverName: 'Juan Pablo D.',
      driverInitials: 'JP',
      driverRating: 4.6,
      meetingPoint: 'Parque Central',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await AuthService().getUserData();
    setState(() => _user = user);
  }

  // Solo el primer nombre
  String get _firstName {
    if (_user == null) return '...';
    return _user!.fullName.trim().split(' ').first;
  }

  // Iniciales del usuario
  String get _initials {
    if (_user == null) return '?';
    final parts = _user!.fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  List<RouteModel> get _filteredRoutes {
    String query = _searchController.text.toLowerCase();
    return _routes.where((r) {
      bool matchesSearch = query.isEmpty ||
          r.origin.toLowerCase().contains(query) ||
          r.destination.toLowerCase().contains(query);
      if (!matchesSearch) return false;
      if (_selectedFilter == 0) return true;
      if (_selectedFilter == 1) {
        int hour = int.tryParse(r.time.split(':')[0]) ?? 0;
        return hour >= 5 && hour < 12;
      }
      if (_selectedFilter == 2) {
        int hour = int.tryParse(r.time.split(':')[0]) ?? 0;
        return hour >= 12 && hour < 18;
      }
      if (_selectedFilter == 3) {
        int hour = int.tryParse(r.time.split(':')[0]) ?? 0;
        return hour >= 18 || hour < 5;
      }
      return true;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      body: SafeArea(
        child: Column(
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
                  // Avatar → navega al perfil
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfileScreen(),
                      ),
                    ),
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
                            onTap: () =>
                                setState(() => _selectedFilter = i),
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

                    // Título + Ver todas
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

                    // Lista de rutas
                    _filteredRoutes.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Text(
                                'No hay rutas disponibles',
                                style: TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _filteredRoutes.length,
                            itemBuilder: (_, i) => RouteCard(
                              route: _filteredRoutes[i],
                              onTap: () {
                                // TODO: navegar a detalle de ruta
                              },
                            ),
                          ),

                    const SizedBox(height: 20),

                    // Botón Publicar Ruta
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // TODO: navegar a PublicarRutaScreen
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
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentNavIndex,
        onTap: (i) => setState(() => _currentNavIndex = i),
      ),
    );
  }
}