import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/route_model.dart';
import '../services/route_service.dart';
import '../theme/app_theme.dart';

class EditarRutaScreen extends StatefulWidget {
  final RouteModel route;

  const EditarRutaScreen({super.key, required this.route});

  @override
  State<EditarRutaScreen> createState() => _EditarRutaScreenState();
}

class _EditarRutaScreenState extends State<EditarRutaScreen> {
  late final TextEditingController _timeController;
  late final TextEditingController _priceController;

  int _selectedSeats = 1;
  bool _loading = false;

  bool get _isBlocked =>
      widget.route.status == RouteStatus.enCurso ||
      widget.route.status == RouteStatus.finalizada ||
      widget.route.status == 'Cancelada';

  @override
  void initState() {
    super.initState();
    _selectedSeats = widget.route.availableSeats.clamp(1, 4);
    _timeController = TextEditingController(text: widget.route.time);
    _priceController = TextEditingController(
      text: widget.route.price.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _timeController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final parts = _timeController.text.split(':');
    final initialHour = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
    final initialMinute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );

    if (picked != null) {
      final hour12 = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
      final m = picked.minute.toString().padLeft(2, '0');
      final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
      _timeController.text = '$hour12:$m $period';
    }
  }

  String? _validate() {
    if (_timeController.text.trim().isEmpty) return 'Ingresa la hora de salida';
    final price = double.tryParse(
      _priceController.text.trim().replaceAll('.', '').replaceAll(',', ''),
    );
    if (price == null || price <= 0) return 'El precio debe ser mayor a 0';
    return null;
  }

  Future<void> _handleSave() async {
    final error = _validate();
    if (error != null) {
      _showError(error);
      return;
    }

    setState(() => _loading = true);
    final result = await RouteService().updateRoute(
      routeId: widget.route.id,
      time: _timeController.text.trim(),
      availableSeats: _selectedSeats,
      price: double.parse(
        _priceController.text.trim().replaceAll('.', '').replaceAll(',', ''),
      ),
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (result == 'ok') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ruta actualizada correctamente'),
          backgroundColor: AppColors.accentGreen,
        ),
      );
      Navigator.pop(context, true);
    } else {
      _showError(result);
    }
  }

  Future<void> _handleCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '¿Cancelar esta ruta?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        content: const Text(
          'Todos los pasajeros con cupo aceptado serán notificados. Esta acción no se puede deshacer.',
          style: TextStyle(fontSize: 13, color: AppColors.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Volver',
              style: TextStyle(color: AppColors.textMedium),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sí, cancelar',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);
    final result = await RouteService().cancelRoute(
      routeId: widget.route.id,
      origin: widget.route.origin,
      destination: widget.route.destination,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (result == 'ok') {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      _showError(result);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F1),
        appBar: AppBar(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Editar ruta',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isBlocked) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.orange.shade700, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Esta ruta no puede modificarse porque su estado es "${widget.route.status}".',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              _label('Hora de salida'),
              TextFormField(
                controller: _timeController,
                readOnly: true,
                onTap: _isBlocked ? null : _pickTime,
                style: const TextStyle(fontSize: 14, color: AppColors.textDark),
                decoration: _inputDecoration(
                  hint: 'HH:mm',
                  icon: Icons.access_time,
                ),
              ),

              const SizedBox(height: 16),

              _label('Asientos disponibles'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: _selectedSeats,
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.textMedium),
                    items: [1, 2, 3, 4]
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(
                                '$s cupo${s > 1 ? 's' : ''}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ))
                        .toList(),
                    onChanged: _isBlocked ? null : (v) => setState(() => _selectedSeats = v ?? 1),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              _label('Precio'),
              TextFormField(
                controller: _priceController,
                enabled: !_isBlocked,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
                ],
                style: const TextStyle(fontSize: 14, color: AppColors.textDark),
                decoration: _inputDecoration(
                  hint: 'Ej: 2500',
                  icon: Icons.attach_money,
                ),
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: (_loading || _isBlocked) ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentGreen,
                    disabledBackgroundColor:
                        AppColors.accentGreen.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Guardar cambios',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: (_loading || _isBlocked) ? null : _handleCancel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    disabledBackgroundColor:
                        Colors.red.shade700.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Cancelar ruta',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMedium,
          ),
        ),
      );

  InputDecoration _inputDecoration({required String hint, required IconData icon}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textPlaceholder),
        prefixIcon: Icon(icon, color: AppColors.textLight, size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accentGreen, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.borderDefault.withValues(alpha: 0.5)),
        ),
      );
}
