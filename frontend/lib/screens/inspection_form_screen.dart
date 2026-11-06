import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/inspection_provider.dart';

class InspectionFormScreen extends StatefulWidget {
  const InspectionFormScreen({super.key});

  @override
  State<InspectionFormScreen> createState() => _InspectionFormScreenState();
}

class _InspectionFormScreenState extends State<InspectionFormScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedModel;
  String? _selectedStation;
  String? _selectedShift = 'AM';
  final TextEditingController _auditorController = TextEditingController();

  final Map<int, String> _visualResults = {};
  final Map<int, TextEditingController> _numericControllers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<InspectionProvider>(
        context,
        listen: false,
      ).fetchModelsAndStations();
    });
  }

  @override
  void dispose() {
    _auditorController.dispose();
    for (var controller in _numericControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onModelChanged(String? newModel) {
    setState(() {
      _selectedModel = newModel;
      _selectedStation = null;
      _visualResults.clear();
      _numericControllers.clear();
    });
    if (newModel != null) {
      Provider.of<InspectionProvider>(
        context,
        listen: false,
      ).updateStationsForModel(newModel);
    }
  }

  void _onStationChanged(String? newStation) {
    setState(() {
      _selectedStation = newStation;
      _visualResults.clear();
      _numericControllers.clear();
    });
    if (_selectedModel != null && newStation != null) {
      Provider.of<InspectionProvider>(
        context,
        listen: false,
      ).loadStationSpecs(_selectedModel!, newStation);
    }
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<InspectionProvider>(context, listen: false);
    final specs = provider.currentSpecs;

    final detailsList = [];

    for (var rawSpec in specs) {
      final spec = Map<String, dynamic>.from(rawSpec as Map);
      final String itemKey = spec['item_key'] ?? '';
      final String itemLabel = spec['item_label'] ?? '';
      final String dataType = spec['data_type'] ?? 'numeric';

      if (dataType == 'boolean') {
        detailsList.add({
          'item_key': itemKey,
          'item_label': itemLabel,
          'visual_status': _visualResults[spec['id']] ?? 'OK',
          'measured_value': null,
        });
      } else {
        final double? val = double.tryParse(
          _numericControllers[spec['id']]?.text ?? '',
        );
        detailsList.add({
          'item_key': itemKey,
          'item_label': itemLabel,
          'visual_status': null,
          'measured_value': val,
        });
      }
    }

    final Map<String, dynamic> payload = {
      'model_code': _selectedModel,
      'station_code': _selectedStation,
      'auditor_name': _auditorController.text.trim(),
      'shift': _selectedShift,
      'details': detailsList,
    };

    final bool success = await provider.sendInspection(payload);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('گزارش بازرسی با موفقیت ثبت شد.'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _selectedStation = null;
          _visualResults.clear();
          _numericControllers.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطا در ثبت اطلاعات در سرور.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<InspectionProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/goldiran_logo.png', height: 24),
            const SizedBox(width: 8),
            const Text(
              'ثبت فرم بازرسی',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedModel,
                  decoration: const InputDecoration(
                    labelText: 'انتخاب مدل محصول',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.kitchen),
                  ),
                  items: provider.availableModels.map((m) {
                    return DropdownMenuItem(value: m, child: Text(m));
                  }).toList(),
                  onChanged: _onModelChanged,
                  validator: (v) =>
                      v == null ? 'لطفاً مدل را انتخاب کنید' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedStation,
                  decoration: const InputDecoration(
                    labelText: 'انتخاب ایستگاه کاری',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.build),
                  ),
                  items: provider.currentAvailableStations.map((s) {
                    return DropdownMenuItem(value: s, child: Text(s));
                  }).toList(),
                  onChanged: _onStationChanged,
                  validator: (v) =>
                      v == null ? 'لطفاً ایستگاه را انتخاب کنید' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _auditorController,
                  decoration: const InputDecoration(
                    labelText: 'نام بازرس',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'نام بازرس الزامی است'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedShift,
                  decoration: const InputDecoration(
                    labelText: 'شیفت کاری',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.access_time),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'AM', child: Text('روز (AM)')),
                    DropdownMenuItem(value: 'PM', child: Text('عصر (PM)')),
                    DropdownMenuItem(value: 'NIGHT', child: Text('شب (NIGHT)')),
                  ],
                  onChanged: (val) => setState(() => _selectedShift = val),
                ),
                const SizedBox(height: 20),
                const Divider(thickness: 2),
                const Text(
                  'آیتم‌های کنترلی ایستگاه:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                if (provider.isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (provider.currentSpecs.isEmpty)
                  const Text('هیچ استانداری برای این ایستگاه یافت نشد.')
                else
                  ...provider.currentSpecs.map((rawSpec) {
                    final spec = Map<String, dynamic>.from(rawSpec as Map);
                    final int specId = spec['id'];
                    final String label = spec['item_label'] ?? '';
                    final String dataType = spec['data_type'] ?? 'numeric';

                    if (dataType == 'boolean') {
                      _visualResults.putIfAbsent(specId, () => 'OK');
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          title: Text(
                            label,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          trailing: ToggleButtons(
                            isSelected: [
                              _visualResults[specId] == 'OK',
                              _visualResults[specId] == 'NG',
                            ],
                            selectedColor: Colors.white,
                            fillColor: _visualResults[specId] == 'OK'
                                ? Colors.green
                                : const Color(0xFFE30613),
                            borderRadius: BorderRadius.circular(8),
                            onPressed: (idx) {
                              setState(() {
                                _visualResults[specId] = idx == 0 ? 'OK' : 'NG';
                              });
                            },
                            children: const [
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('OK'),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('NG'),
                              ),
                            ],
                          ),
                        ),
                      );
                    } else {
                      _numericControllers.putIfAbsent(
                        specId,
                        () => TextEditingController(),
                      );
                      final double? minV = spec['min_value']?.toDouble();
                      final double? maxV = spec['max_value']?.toDouble();
                      final String unit = spec['unit'] ?? '';

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$label (بازه مجاز: $minV تا $maxV $unit)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _numericControllers[specId],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  labelText: 'مقدار اندازه‌گیری شده ($unit)',
                                  border: const OutlineInputBorder(),
                                ),
                                validator: (val) {
                                  if (val == null || val.isEmpty) {
                                    return 'وارد کردن مقدار الزامی است';
                                  }
                                  if (double.tryParse(val) == null) {
                                    return 'لطفاً عدد معتبر وارد کنید';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  }),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE30613),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'ثبت و ارسال گزارش',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}