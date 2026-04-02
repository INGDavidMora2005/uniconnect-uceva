import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/route_model.dart';
import '../services/route_service.dart';
import '../services/auth_service.dart';
import '../widgets/primary_button.dart';

class PublicarRutaScreen extends StatefulWidget {
  const PublicarRutaScreen({super.key});

  @override
  State<PublicarRutaScreen> createState() => _PublicarRutaScreenState();
}

class _PublicarRutaScreenState extends State<PublicarRutaScreen> {
  final _formKey                = GlobalKey<FormState>();
  final _originController       = TextEditingController();
  final _destinationController  = TextEditingController();
  final _meetingPointController = TextEditingController();
  final _noteController         = TextEditingController();
  final _priceController        = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _selectedSeats = 1;
  bool _isLoading = false;

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _meetingPointController.dispose();
    _noteController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.accentGreen,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.accentGreen,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  String get _dateText {
    if (_selectedDate == null) return 'DD/MM/AA';
    final d = _selectedDate!;
    final now = DateTime.now();
    if (d.day == now.day && d.month == now.month && d.year == now.year) {
      return 'Hoy';
    }
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year.toString().substring(2)}';
  }

  String get _timeText {
    if (_selectedTime == null) return 'HH:MM';
    final h = _selectedTime!.hourOfPeriod == 0 ? 12 : _selectedTime!.hourOfPeriod;
    final m = _selectedTime!.minute.toString().padLeft(2, '0');
    final period = _selectedTime!.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  void _handlePublish() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) { _showError('Selecciona una fecha'); return; }
    if (_selectedTime == null) { _showError('Selecciona una hora'); return; }

    setState(() => _isLoading = true);

    try {
      final user = await AuthService().getUserData();
      if (user == null) {
        _showError('No se pudo obtener tu información');
        setState(() => _isLoading = false);
        return;
      }

      final parts = user.fullName.trim().split(' ');
      final initials = parts.length >= 2
          ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
          : parts[0][0].toUpperCase();

      final priceText = _priceController.text.trim()
          .replaceAll('.', '').replaceAll(',', '');
      final price = double.tryParse(priceText) ?? 0;

      final route = RouteModel(
        id:             '',
        origin:         _originController.text.trim(),
        destination:    _destinationController.text.trim(),
        date:           _dateText,
        time:           _timeText,
        price:          price,
        availableSeats: _selectedSeats,
        totalSeats:     _selectedSeats,
        driverName:     parts[0] + (parts.length > 1 ? ' ${parts[1][0]}.' : ''),
        driverInitials: initials,
        driverRating:   user.rating,
        meetingPoint:   _meetingPointController.text.trim(),
        note:           _noteController.text.trim().isEmpty
                            ? null : _noteController.text.trim(),
        driverId:       AuthService().currentUser?.uid,
        status:         'Activa',
      );

      final result = await RouteService().publishRoute(route);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result == 'Ruta publicada exitosamente.') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Ruta publicada exitosamente!'),
            backgroundColor: AppColors.accentGreen,
          ),
        );
        Navigator.pop(context, true);
      } else {
        _showError(result);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error: ${e.toString()}');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  Widget _fieldLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textMedium,
      ),
    ),
  );

  Widget _inputDecoration({
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14, color: AppColors.textDark),
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: AppColors.backgroundWhite,
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
            borderSide:
                const BorderSide(color: AppColors.accentGreen, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
        ),
        validator: validator,
      );

  Widget _selectorBox({
    required String text,
    required VoidCallback onTap,
    required IconData icon,
    required bool isSelected,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.backgroundWhite,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.accentGreen : AppColors.borderDefault,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? AppColors.accentGreen
                    : AppColors.textPlaceholder,
              ),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected
                      ? AppColors.textDark
                      : AppColors.textPlaceholder,
                ),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header verde oscuro ──────────────────────────
            Container(
              color: AppColors.primaryGreen,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Publicar Ruta',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // ── Formulario ───────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Origen
                      _fieldLabel('Origen'),
                      _inputDecoration(
                        hint: '¿Desde dónde sales?',
                        controller: _originController,
                        validator: (v) => v == null || v.isEmpty
                            ? 'Ingresa el origen' : null,
                      ),
                      const SizedBox(height: 16),

                      // Destino (editable)
                      _fieldLabel('Destino'),
                      _inputDecoration(
                        hint: '¿A dónde vas?',
                        controller: _destinationController,
                        validator: (v) => v == null || v.isEmpty
                            ? 'Ingresa el destino' : null,
                      ),
                      const SizedBox(height: 16),

                      // Fecha y Hora
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _fieldLabel('Fecha'),
                                _selectorBox(
                                  text: _dateText,
                                  onTap: _pickDate,
                                  icon: Icons.calendar_today_outlined,
                                  isSelected: _selectedDate != null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _fieldLabel('Hora'),
                                _selectorBox(
                                  text: _timeText,
                                  onTap: _pickTime,
                                  icon: Icons.access_time_outlined,
                                  isSelected: _selectedTime != null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Cupos y Precio
                      Row(
                        children: [
                          // Cupos
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _fieldLabel('Cupos disponibles'),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: AppColors.backgroundWhite,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: AppColors.borderDefault),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      isExpanded: true,
                                      value: _selectedSeats,
                                      icon: const Icon(
                                        Icons.arrow_drop_down,
                                        color: AppColors.textMedium,
                                      ),
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
                                      onChanged: (v) => setState(
                                          () => _selectedSeats = v ?? 1),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Precio
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _fieldLabel('Aporte por pasajero'),
                                _inputDecoration(
                                  hint: '\$ 0.000',
                                  controller: _priceController,
                                  keyboardType: TextInputType.number,
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Ingresa el aporte' : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Punto de encuentro
                      _fieldLabel('Punto de encuentro'),
                      _inputDecoration(
                        hint: 'Describe el punto exacto',
                        controller: _meetingPointController,
                        validator: (v) => v == null || v.isEmpty
                            ? 'Ingresa el punto de encuentro' : null,
                      ),
                      const SizedBox(height: 16),

                      // Nota adicional
                      _fieldLabel('Nota adicional (Opcional)'),
                      _inputDecoration(
                        hint: 'Ej: No se aceptan mascotas, bebidas ...',
                        controller: _noteController,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 28),

                      // Botón Publicar
                      PrimaryButton(
                        text: 'Publicar Ruta',
                        onPressed: _handlePublish,
                        isLoading: _isLoading,
                      ),
                      const SizedBox(height: 12),

                      // Botón Cancelar
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textMedium,
                            side: const BorderSide(
                                color: AppColors.borderDefault),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}