import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/inspection_provider.dart';

class SpecManagementScreen extends StatefulWidget {
  const SpecManagementScreen({super.key});

  @override
  State<SpecManagementScreen> createState() => _SpecManagementScreenState();
}

class _SpecManagementScreenState extends State<SpecManagementScreen> {
  String? _selectedModel;
  String? _selectedStation;
  final TextEditingController _modelController = TextEditingController();
  List _specItems = [];
  bool _isLoadingSpecs = false;

  // لیست ۱۲ ایستگاه کاری استاندارد کارخانه گلدایران
  final List<String> _factoryStations = [
    'خط تزریق فوم (Case PU)',
    'مونتاژ بدنه و شاسی (Body & Chassis)',
    'نصب کمپرسور و مدار مبرد (Compressor & Refrigeration)',
    'وکیوم و شارژ گاز (Vacuum & Gas Charging)',
    'تست‌های الکتریکی و ایمنی (Electrical & Safety)',
    'مونتاژ قطعات داخلی و درب‌ها (Interior & Doors)',
    'تست نهایی عملکردی (Final Functional Test)',
    'بازرسی ظاهری و بدنه (Visual & Cabinet Inspection)',
    'بسته‌بندی و شیرینگ (Packaging & Shrink)',
    'کنترل کیفیت انبار قطعات (Parts Warehouse QC)',
    'آزمایشگاه کنترل کیفیت (QC Laboratory)',
    'بازرسی خطوط تولید تلویزیون و صوتی (TV & Audio Line)',
  ];

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

  void _loadExistingSpecs() async {
    if (_selectedModel == null ||
        _selectedModel!.isEmpty ||
        _selectedStation == null ||
        _selectedStation!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لطفاً ابتدا مدل و ایستگاه کاری را انتخاب کنید',
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoadingSpecs = true);
    final provider = Provider.of<InspectionProvider>(context, listen: false);
    await provider.loadStationSpecs(_selectedModel!, _selectedStation!);

    setState(() {
      _specItems = List.from(
        provider.currentSpecs.map(
          (spec) => {
            'item_key': spec['item_key'] ?? '',
            'item_label': spec['item_label'] ?? '',
            'data_type': spec['data_type'] ?? 'numeric',
            'min_value': spec['min_value'],
            'max_value': spec['max_value'],
            'unit': spec['unit'],
          },
        ),
      );
      _isLoadingSpecs = false;
    });

    if (_specItems.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'استانداردهای ثبت‌شده این ایستگاه بارگذاری شد',
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'هیچ استاندارد قبلی برای این ایستگاه یافت نشد. می‌توانید آیتم جدید اضافه کنید.',
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  void _createNewModelPrompt() {
    final TextEditingController newModelCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.add_box, color: Color(0xFFE30613)),
            SizedBox(width: 8),
            Text('تعریف مدل محصول جدید', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: TextField(
          controller: newModelCtrl,
          decoration: const InputDecoration(
            labelText: 'کد یا نام مدل جدید (مثلا GSS-R7641)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('انصراف', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE30613),
            ),
            onPressed: () {
              if (newModelCtrl.text.trim().isNotEmpty) {
                setState(() {
                  _selectedModel = newModelCtrl.text.trim();
                  _modelController.text = _selectedModel!;
                  _specItems.clear();
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'مدل "$_selectedModel" ایجاد شد. حالا ایستگاه و آیتم‌ها را اضافه کنید.',
                      textDirection: TextDirection.rtl,
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text(
              'ایجاد مدل',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteEntireModel() {
    if (_selectedModel == null || _selectedModel!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لطفاً مدلی را برای حذف انتخاب کنید',
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('حذف کامل مدل محصول', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(
          'آیا از حذف کامل مدل "$_selectedModel" و تمامی استانداردهای آن اطمینان دارید؟ این عمل غیرقابل بازگشت است.',
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = Provider.of<InspectionProvider>(
                context,
                listen: false,
              );
              // حذف تمامی ایستگاه‌های این مدل از طریق سرور یا پاکسازی محلی
              bool success = await provider.deleteEntireModel(_selectedModel!);
              if (mounted) {
                setState(() {
                  _selectedModel = null;
                  _modelController.clear();
                  _selectedStation = null;
                  _specItems.clear();
                });
                provider.fetchModelsAndStations();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'مدل مورد نظر با موفقیت حذف شد',
                      textDirection: TextDirection.rtl,
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text(
              'حذف کامل مدل',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteStation() {
    if (_selectedModel == null || _selectedStation == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف ایستگاه کاری', textDirection: TextDirection.rtl),
        content: Text(
          'آیا از حذف کامل ایستگاه "$_selectedStation" برای مدل $_selectedModel اطمینان دارید؟',
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = Provider.of<InspectionProvider>(
                context,
                listen: false,
              );
              bool success = await provider.deleteStationFromModel(
                _selectedModel!,
                _selectedStation!,
              );
              if (mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'ایستگاه با موفقیت حذف شد',
                      textDirection: TextDirection.rtl,
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
                setState(() => _specItems.clear());
              }
            },
            child: const Text(
              'حذف ایستگاه',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showItemDialog({required bool isEdit, required int index}) {
    final item = isEdit ? _specItems[index] : null;
    final itemKeyCtrl = TextEditingController(
      text: isEdit ? item['item_key'] : '',
    );
    final itemLabelCtrl = TextEditingController(
      text: isEdit ? item['item_label'] : '',
    );
    String dataType = isEdit ? (item['data_type'] ?? 'numeric') : 'numeric';
    final minCtrl = TextEditingController(
      text: isEdit ? (item['min_value']?.toString() ?? '') : '',
    );
    final maxCtrl = TextEditingController(
      text: isEdit ? (item['max_value']?.toString() ?? '') : '',
    );
    final unitCtrl = TextEditingController(
      text: isEdit ? (item['unit'] ?? '') : '',
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(
                    isEdit ? Icons.edit : Icons.playlist_add,
                    color: const Color(0xFFE30613),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEdit ? 'ویرایش آیتم کنترلی' : 'افزودن آیتم کنترلی جدید',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: itemKeyCtrl,
                        decoration: const InputDecoration(
                          labelText: 'کلید سیستمی (مثلا temp_sensor)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.key),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: itemLabelCtrl,
                        decoration: const InputDecoration(
                          labelText: 'عنوان نمایشی آیتم (مثلا دمای کمپرسور)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.label),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: dataType,
                        items: const [
                          DropdownMenuItem(
                            value: 'numeric',
                            child: Text('عددی (Numeric با حد مجاز)'),
                          ),
                          DropdownMenuItem(
                            value: 'boolean',
                            child: Text('تایید / رد (OK / NG)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            dialogSetState(() => dataType = val);
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'نوع داده کنترلی',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                      ),
                      if (dataType == 'numeric') ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: minCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'حداقل مجاز',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: maxCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'حداکثر مجاز',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: unitCtrl,
                          decoration: const InputDecoration(
                            labelText: 'واحد اندازه‌گیری (مثلا °C یا mm)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.straighten),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'انصراف',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE30613),
                  ),
                  onPressed: () {
                    if (itemKeyCtrl.text.isEmpty ||
                        itemLabelCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'لطفاً کلید و عنوان آیتم را وارد کنید',
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                      );
                      return;
                    }
                    setState(() {
                      final newItem = {
                        'item_key': itemKeyCtrl.text.trim(),
                        'item_label': itemLabelCtrl.text.trim(),
                        'data_type': dataType,
                        'min_value': dataType == 'numeric'
                            ? double.tryParse(minCtrl.text)
                            : null,
                        'max_value': dataType == 'numeric'
                            ? double.tryParse(maxCtrl.text)
                            : null,
                        'unit': dataType == 'numeric'
                            ? unitCtrl.text.trim()
                            : null,
                      };
                      if (isEdit) {
                        _specItems[index] = newItem;
                      } else {
                        _specItems.add(newItem);
                      }
                    });
                    Navigator.pop(ctx);
                  },
                  child: Text(
                    isEdit ? 'ذخیره تغییرات' : 'تایید و افزودن',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _saveSpecsToServer() async {
    String modelCode = _modelController.text.trim().isNotEmpty
        ? _modelController.text.trim()
        : (_selectedModel ?? '');
    String stationCode = _selectedStation ?? '';

    if (modelCode.isEmpty || stationCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لطفاً مدل محصول و ایستگاه کاری را انتخاب کنید',
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_specItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'حداقل یک آیتم کنترلی برای این ایستگاه ثبت کنید',
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final provider = Provider.of<InspectionProvider>(context, listen: false);
    final payload = {
      'model_code': modelCode,
      'station_code': stationCode,
      'specifications': _specItems,
    };

    final success = await provider.saveStationSpecs(payload);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'استانداردها با موفقیت روی سرور ذخیره شد',
              textDirection: TextDirection.rtl,
            ),
            backgroundColor: Colors.green,
          ),
        );
        provider.fetchModelsAndStations();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'خطا در ارتباط با سرور',
              textDirection: TextDirection.rtl,
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<InspectionProvider>(context);
    final List<String> availableModels = provider.availableModels
        .map((e) => e.toString())
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('مدیریت استانداردها و مشخصات کیفیت'),
        backgroundColor: const Color(0xFFE30613),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // بخش انتخاب مدل و دکمه‌های ایجاد / حذف مدل
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              value: availableModels.contains(_selectedModel)
                                  ? _selectedModel
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'انتخاب از مدل‌های ثبت‌شده قبلی',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(
                                  Icons.list_alt,
                                  color: Color(0xFFE30613),
                                ),
                              ),
                              items: availableModels
                                  .map<DropdownMenuItem<String>>((
                                    String model,
                                  ) {
                                    return DropdownMenuItem<String>(
                                      value: model,
                                      child: Text(model),
                                    );
                                  })
                                  .toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedModel = val;
                                  _modelController.text = val ?? '';
                                  _specItems.clear();
                                });
                                provider.updateStationsForModel(val);
                              },
                              hint: const Text('انتخاب مدل موجود'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // دکمه ایجاد مدل جدید
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 10,
                              ),
                            ),
                            onPressed: _createNewModelPrompt,
                            icon: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 18,
                            ),
                            label: const Text(
                              'مدل جدید',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // دکمه حذف کامل مدل
                          IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.red.shade50,
                            ),
                            onPressed: _confirmDeleteEntireModel,
                            icon: const Icon(
                              Icons.delete_forever,
                              color: Colors.red,
                            ),
                            tooltip: 'حذف کامل این مدل',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _modelController,
                        onChanged: (val) =>
                            setState(() => _selectedModel = val),
                        decoration: const InputDecoration(
                          labelText: 'کد یا نام مدل محصول (قابل ویرایش)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.devices),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _factoryStations.contains(_selectedStation)
                                  ? _selectedStation
                                  : null,
                              decoration: const InputDecoration(
                                labelText:
                                    'ایستگاه کاری (انتخاب از ۱۲ ایستگاه)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.work_outline),
                              ),
                              items: _factoryStations
                                  .map<DropdownMenuItem<String>>((String st) {
                                    return DropdownMenuItem<String>(
                                      value: st,
                                      child: Text(
                                        st,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  })
                                  .toList(),
                              onChanged: (st) {
                                setState(() {
                                  _selectedStation = st;
                                });
                                if (_selectedModel != null &&
                                    _selectedModel!.isNotEmpty) {
                                  _loadExistingSpecs();
                                }
                              },
                              hint: const Text('انتخاب ایستگاه کاری'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 14,
                              ),
                            ),
                            onPressed: _loadExistingSpecs,
                            child: const Text(
                              'بارگذاری',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'آیتم‌های کنترلی استاندارد:',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      if (_selectedStation != null)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          onPressed: _confirmDeleteStation,
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('حذف ایستگاه'),
                        ),
                      const SizedBox(width: 6),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE30613),
                        ),
                        onPressed: () =>
                            _showItemDialog(isEdit: false, index: -1),
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text(
                          'افزودن آیتم',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(thickness: 2),
              Expanded(
                child: _isLoadingSpecs
                    ? const Center(child: CircularProgressIndicator())
                    : _specItems.isEmpty
                    ? const Center(
                        child: Text(
                          'هنوز هیچ آیتم کنترلی‌ای برای این ایستگاه ثبت نشده است.\nاز دکمه «افزودن آیتم» استفاده کنید.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _specItems.length,
                        itemBuilder: (context, index) {
                          final item = _specItems[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            elevation: 2,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFE30613),
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(
                                '${item['item_label']} (${item['item_key']})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                'نوع: ${item['data_type']} | حد: ${item['min_value'] ?? "-"} تا ${item['max_value'] ?? "-"} | واحد: ${item['unit'] ?? "-"}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                    onPressed: () => _showItemDialog(
                                      isEdit: true,
                                      index: index,
                                    ),
                                    tooltip: 'ویرایش آیتم',
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _specItems.removeAt(index);
                                      });
                                    },
                                    tooltip: 'حذف آیتم',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveSpecsToServer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE30613),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.cloud_upload, color: Colors.white),
                  label: const Text(
                    'ذخیره و ثبت نهایی استانداردها در سرور',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
