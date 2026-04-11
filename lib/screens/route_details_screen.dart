import 'package:flutter/material.dart';
import '../models/route_model.dart';
import '../theme/app_theme.dart';

import 'mapa_trayecto_screen.dart';

class RouteDetailsScreen extends StatelessWidget {
  final RouteModel route;
  final bool isDriver;

  const RouteDetailsScreen({
    super.key,
    required this.route,
    required this.isDriver,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        title: const Text(
          'Detalles del viaje',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info principal
            Text(
              '${route.origin} → ${route.destination}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${route.date} · ${route.time}',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Precio: ${route.priceFormatted}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.accentGreen,
              ),
            ),
            const SizedBox(height: 16),

            // Conductor
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.accentGreen,
                  child: Text(
                    route.driverInitials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route.driverName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        '⭐ ${route.driverRating}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Detalles adicionales
            if (route.meetingPoint.isNotEmpty) ...[
              Text(
                'Punto de encuentro: ${route.meetingPoint}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (route.note != null && route.note!.isNotEmpty) ...[
              Text(
                'Nota: ${route.note}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              'Cupos disponibles: ${route.availableSeats}/${route.totalSeats}',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 16),

            // Estado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: route.statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: route.statusColor),
              ),
              child: Text(
                route.statusLabel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: route.statusColor,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Mapa si en curso
            if (route.status == RouteStatus.enCurso) ...[
              const Text(
                'Trayecto en vivo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 300,
                child: MapaTrayectoScreen(
                  route: route,
                  isDriver: isDriver,
                  isEmbedded: true,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}