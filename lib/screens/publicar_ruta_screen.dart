import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/route_model.dart';
import '../services/route_service.dart';
import '../services/auth_service.dart';
import '../services/geocoding_service.dart';
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

  // Coordenadas seleccionadas por el usuario via sugerencia
  double? _originLat;
  double? _originLng;
  double? _destLat;
  double? _destLng;

  // Timer para debounce del autocomplete
  Timer? _originDebounce;
  Timer? _destDebounce;

  // Lista de sugerencias activas
  List<PlaceSuggestion> _originSuggestions = [];
  List<PlaceSuggestion> _destSuggestions = [];
  bool _showOriginSuggestions = false;
  bool _showDestSuggestions = false;

  // Anti race-condition para debounce
  String _lastOriginQuery = '';
  String _lastDestQuery = '';

  // Indicadores de carga para sugerencias
  bool _isLoadingOriginSugg = false;
  bool _isLoadingDestSugg = false;

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _meetingPointController.dispose();
    _noteController.dispose();
    _priceController.dispose();
    _originDebounce?.cancel();
    _destDebounce?.cancel();
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

  String _shortName(String displayName) {
    final parts = displayName.split(',');
    return parts.first.trim();
  }

  void _onOriginChanged(String value) {
    // Limpiar coordenadas cuando el usuario edita manualmente
    _originLat = null;
    _originLng = null;

    _originDebounce?.cancel();
    if (value.length < 3) {
      setState(() => _showOriginSuggestions = false);
      return;
    }
    _originDebounce = Timer(const Duration(milliseconds: 400), () async {
      final querySnapshot = value;
      _lastOriginQuery = querySnapshot;
      setState(() => _isLoadingOriginSugg = true);
      final suggestions = await GeocodingService().getSuggestions(querySnapshot);
      if (mounted && _lastOriginQuery == querySnapshot) {
        setState(() {
          _isLoadingOriginSugg = false;
          _originSuggestions = suggestions;
          _showOriginSuggestions = suggestions.isNotEmpty;
          _showDestSuggestions = false;
        });
      }
    });
  }

  void _onDestChanged(String value) {
    // Limpiar coordenadas cuando el usuario edita manualmente
    _destLat = null;
    _destLng = null;

    _destDebounce?.cancel();
    if (value.length < 3) {
      setState(() => _showDestSuggestions = false);
      return;
    }
    _destDebounce = Timer(const Duration(milliseconds: 400), () async {
      final querySnapshot = value;
      _lastDestQuery = querySnapshot;
      setState(() => _isLoadingDestSugg = true);
      final suggestions = await GeocodingService().getSuggestions(querySnapshot);
      if (mounted && _lastDestQuery == querySnapshot) {
        setState(() {
          _isLoadingDestSugg = false;
          _destSuggestions = suggestions;
          _showDestSuggestions = suggestions.isNotEmpty;
          _showOriginSuggestions = false;
        });
      }
    });
  }

  void _onOriginSuggestionSelected(PlaceSuggestion suggestion) {
    _originController.text = _shortName(suggestion.displayName);
    _originLat = suggestion.lat;
    _originLng = suggestion.lng;
    setState(() => _showOriginSuggestions = false);
  }

  void _onDestSuggestionSelected(PlaceSuggestion suggestion) {
    _destinationController.text = _shortName(suggestion.displayName);
    _destLat = suggestion.lat;
    _destLng = suggestion.lng;
    setState(() => _showDestSuggestions = false);
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

      // 1. Si no se seleccionó sugerencia de origen → intentar geocoding
      if (_originLat == null || _originLng == null) {
        final result = await GeocodingService().geocodeAddress(_originController.text.trim());
        if (result == null) {
          _showError('No se encontraron coordenadas para el origen. Selecciona una sugerencia del listado.');
          setState(() => _isLoading = false);
          return;
        }
        _originLat = result.latitude;
        _originLng = result.longitude;
      }

      // 2. Si no se seleccionó sugerencia de destino → intentar geocoding
      if (_destLat == null || _destLng == null) {
        final result = await GeocodingService().geocodeAddress(_destinationController.text.trim());
        if (result == null) {
          _showError('No se encontraron coordenadas para el destino. Selecciona una sugerencia del listado.');
          setState(() => _isLoading = false);
          return;
        }
        _destLat = result.latitude;
        _destLng = result.longitude;
      }

      // 3. Validar que estén dentro de Colombia
      if (!GeocodingService.isWithinColombia(_originLat!, _originLng!)) {
        _showError('El origen debe estar dentro de Colombia.');
        setState(() => _isLoading = false);
        return;
      }
      if (!GeocodingService.isWithinColombia(_destLat!, _destLng!)) {
        _showError('El destino debe estar dentro de Colombia.');
        setState(() => _isLoading = false);
        return;
      }

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
        originLat:      _originLat,
        originLng:      _originLng,
        destLat:        _destLat,
        destLng:        _destLng,
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

  Widget _autocompleteField({
    required String hint,
    required TextEditingController controller,
    required String? Function(String?) validator,
    required List<PlaceSuggestion> suggestions,
    required bool showSuggestions,
    required void Function(String) onChanged,
    required void Function(PlaceSuggestion) onSuggestionSelected,
    required VoidCallback onDismiss,
    required bool isLoading,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
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
              borderSide: const BorderSide(color: AppColors.accentGreen, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            suffixIcon: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accentGreen,
                      ),
                    ),
                  )
                : null,
          ),
          validator: validator,
          onChanged: onChanged,
          onTapOutside: (_) {
            onDismiss();
            FocusManager.instance.primaryFocus?.unfocus();
          },
        ),
        if (showSuggestions && suggestions.isNotEmpty)
          Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: AppColors.backgroundWhite,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderDefault),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: suggestions.length,
                separatorBuilder: (_, _) => const Divider(
                  height: 1,
                  color: AppColors.borderDefault,
                ),
                itemBuilder: (context, index) {
                  final suggestion = suggestions[index];
                  return InkWell(
                    onTap: () => onSuggestionSelected(suggestion),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Text(
                        suggestion.displayName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textDark,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

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
                      _autocompleteField(
                        hint: '¿Desde dónde sales?',
                        controller: _originController,
                        validator: (v) => v == null || v.isEmpty
                            ? 'Ingresa el origen' : null,
                        suggestions: _originSuggestions,
                        showSuggestions: _showOriginSuggestions,
                        onChanged: _onOriginChanged,
                        onSuggestionSelected: _onOriginSuggestionSelected,
                        onDismiss: () => setState(() {
                          _showOriginSuggestions = false;
                          _showDestSuggestions = false;
                        }),
                        isLoading: _isLoadingOriginSugg,
                      ),
                      const SizedBox(height: 16),

                      // Destino (editable)
                      _fieldLabel('Destino'),
                      _autocompleteField(
                        hint: '¿A dónde vas?',
                        controller: _destinationController,
                        validator: (v) => v == null || v.isEmpty
                            ? 'Ingresa el destino' : null,
                        suggestions: _destSuggestions,
                        showSuggestions: _showDestSuggestions,
                        onChanged: _onDestChanged,
                        onSuggestionSelected: _onDestSuggestionSelected,
                        onDismiss: () => setState(() {
                          _showDestSuggestions = false;
                          _showOriginSuggestions = false;
                        }),
                        isLoading: _isLoadingDestSugg,
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
                                   validator: (v) {
                                     if (v == null || v.isEmpty) return 'Ingresa el aporte';
                                     final parsed = double.tryParse(
                                       v.trim().replaceAll('.', '').replaceAll(',', ''),
                                     );
                                     if (parsed == null || parsed <= 0) return 'El aporte debe ser mayor a \$0';
                                     return null;
                                   },
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