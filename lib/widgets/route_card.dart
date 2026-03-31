import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/route_model.dart';

class RouteCard extends StatelessWidget {
  final RouteModel route;
  final VoidCallback onTap;

  const RouteCard({
    super.key,
    required this.route,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.backgroundWhite,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila superior: ruta + cupos
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${route.origin} → ${route.destination}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: route.isFull
                          ? Colors.red.withOpacity(0.1)
                          : AppColors.accentGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      route.isFull
                          ? 'Lleno'
                          : '${route.availableSeats} Cupos',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: route.isFull
                            ? Colors.red
                            : AppColors.accentGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Fecha, hora y precio
              Text(
                '${route.date} · ${route.time} · ${route.priceFormatted}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(height: 10),
              // Fila inferior: conductor + rating
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.accentGreen,
                        child: Text(
                          route.driverInitials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        route.driverName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundApp,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '⭐ ${route.driverRating}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}