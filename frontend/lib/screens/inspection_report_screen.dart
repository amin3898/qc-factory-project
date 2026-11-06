import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../providers/inspection_provider.dart';

class InspectionReportScreen extends StatefulWidget {
  const InspectionReportScreen({Key? key}) : super(key: key);

  @override
  State<InspectionReportScreen> createState() => _InspectionReportScreenState();
}

class _InspectionReportScreenState extends State<InspectionReportScreen> {
  List _rawReports = [];
  Map<String, List> _groupedReports = {};
  bool _isLoading = true;
  String? _selectedStatusFilter = 'ALL';
  String? _selectedDateFilter;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() {
      _isLoading = true;
    });

    final provider = Provider.of<InspectionProvider>(context, listen: false);
    final baseUrl = provider.baseUrl;

    try {
      String url = '$baseUrl/inspections/report?';
      if (_selectedStatusFilter != null && _selectedStatusFilter != 'ALL') {
        url += 'overall_status=$_selectedStatusFilter&';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List data = json.decode(utf8.decode(response.bodyBytes));
        if (!mounted) return;

        Map<String, List> grouped = {};
        for (var item in data) {
          String rawDate = (item['created_at'] ?? item['inspection_date'] ?? '').toString();
          String date = rawDate.length >= 10 ? rawDate.substring(0, 10) : 'بدون تاریخ';
          
          if (_selectedDateFilter != null && _selectedDateFilter!.isNotEmpty) {
            if (date != _selectedDateFilter) {
              continue;
            }
          }

          String model = item['model_code'] ?? 'بدون مدل';
          String groupKey = '$date|$model';

          if (!grouped.containsKey(groupKey)) {
            grouped[groupKey] = [];
          }
          grouped[groupKey]!.add(item);
        }

        setState(() {
          _rawReports = data;
          _groupedReports = grouped;
          _isLoading = false;
        });
      } else {
        throw Exception('خطا در دریافت داده‌ها از سرور');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در برقراری ارتباط با سرور: $e')),
      );
    }
  }

  void _downloadExcel() async {
    final provider = Provider.of<InspectionProvider>(context, listen: false);
    String url = '${provider.baseUrl}/inspections/export/excel';
    if (_selectedDateFilter != null && _selectedDateFilter!.isNotEmpty) {
      url += '?target_date=$_selectedDateFilter';
    }
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('امکان باز کردن لینک دانلود اکسل وجود ندارد.'),
          ),
        );
      }
    }
  }

  void _showSettingsDialog() {
    final provider = Provider.of<InspectionProvider>(context, listen: false);
    final ipController = TextEditingController(text: provider.serverIp);
    final portController = TextEditingController(text: provider.serverPort);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.settings, color: Color(0xFFE30613)),
            SizedBox(width: 8),
            Text('تنظیمات آدرس سرور (IP)', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                labelText: 'آدرس IP سرور',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: portController,
              decoration: const InputDecoration(
                labelText: 'پورت',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE30613),
            ),
            onPressed: () async {
              await provider.updateServerConfig(
                ipController.text.trim(),
                portController.text.trim(),
              );
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('آدرس سرور با موفقیت به‌روزرسانی شد.'),
                    backgroundColor: Colors.green,
                  ),
                );
                _fetchReports();
              }
            },
            child: const Text('ذخیره', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(int inspectionId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تایید حذف گزارش'),
        content: const Text('آیا از حذف این بازرسی مطمئن هستید؟'),
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
              bool success = await provider.deleteInspection(inspectionId);
              if (mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('گزارش با موفقیت حذف شد.'),
                    backgroundColor: Colors.green,
                  ),
                );
                _fetchReports();
              }
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(Map item) {
    final auditorController = TextEditingController(text: item['auditor_name']);
    String selectedShift = item['shift'] ?? 'AM';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('ویرایش گزارش ایستگاه: ${item['station_code']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: auditorController,
                decoration: const InputDecoration(
                  labelText: 'نام بازرس',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButton<String>(
                value: selectedShift,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'AM', child: Text('روز (AM)')),
                  DropdownMenuItem(value: 'PM', child: Text('عصر (PM)')),
                  DropdownMenuItem(value: 'NIGHT', child: Text('شب (NIGHT)')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedShift = val);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE30613),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final provider = Provider.of<InspectionProvider>(
                  context,
                  listen: false,
                );
                bool success = await provider.updateInspection(
                  item['id'],
                  auditorController.text.trim(),
                  selectedShift,
                );
                if (mounted && success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('اطلاعات با موفقیت به‌روزرسانی شد.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _fetchReports();
                }
              },
              child: const Text(
                'ذخیره تغییرات',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pickFilterDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedDateFilter = picked.toIso8601String().split('T')[0];
      });
      _fetchReports();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDateFilter = null;
    });
    _fetchReports();
  }

  @override
  Widget build(BuildContext context) {
    int totalInspections = 0;
    int okCount = 0;
    int ngCount = 0;

    _groupedReports.values.forEach((list) {
      totalInspections += list.length;
      for (var r in list) {
        if (r['overall_status'] == 'OK') okCount++;
        if (r['overall_status'] == 'NG') ngCount++;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('گزارش بازرسی‌ها'),
        backgroundColor: const Color(0xFFE30613),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
            tooltip: 'تنظیمات IP سرور',
          ),
          ElevatedButton.icon(
            onPressed: _downloadExcel,
            icon: const Icon(Icons.file_download, size: 18),
            label: const Text('Excel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchReports,
            tooltip: 'به‌روزرسانی',
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'کل ایستگاه‌ها',
                      '$totalInspections',
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      'تست سالم (OK)',
                      '$okCount',
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      'تست معیوب (NG)',
                      '$ngCount',
                      const Color(0xFFE30613),
                    ),
                  ),
                ],
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 6.0,
                ),
                child: Row(
                  children: [
                    const Text(
                      'فیلتر تاریخ:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      avatar: const Icon(Icons.calendar_month, size: 16),
                      label: Text(_selectedDateFilter ?? 'همه تاریخ‌ها'),
                      onPressed: _pickFilterDate,
                    ),
                    if (_selectedDateFilter != null)
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Color(0xFFE30613),
                          size: 18,
                        ),
                        onPressed: _clearDateFilter,
                      ),
                    const Spacer(),
                    const Text(
                      'وضعیت:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    DropdownButton<String>(
                      value: _selectedStatusFilter,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('همه')),
                        DropdownMenuItem(value: 'OK', child: Text('فقط سالم')),
                        DropdownMenuItem(value: 'NG', child: Text('فقط معیوب')),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedStatusFilter = val;
                        });
                        _fetchReports();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _groupedReports.isEmpty
                  ? const Center(
                      child: Text('هیچ گزارشی برای این تاریخ یا وضعیت یافت نشد.'),
                    )
                  : ListView.builder(
                      itemCount: _groupedReports.keys.length,
                      itemBuilder: (context, index) {
                        String groupKey = _groupedReports.keys.elementAt(index);
                        List stationList = _groupedReports[groupKey]!;

                        List<String> parts = groupKey.split('|');
                        String date = parts[0];
                        String modelCode = parts[1];

                        bool hasNg = stationList.any(
                          (s) => s['overall_status'] == 'NG',
                        );
                        Color statusColor = hasNg
                            ? const Color(0xFFE30613)
                            : Colors.green;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: statusColor, width: 2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: statusColor.withOpacity(0.2),
                              child: Icon(
                                hasNg
                                    ? Icons.error_outline
                                    : Icons.check_circle_outline,
                                color: statusColor,
                              ),
                            ),
                            title: Text(
                              'گزارش بازرسی مدل: $modelCode',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              'تاریخ بازرسی: $date | تعداد ایستگاه‌ها: ${stationList.length}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                color: Colors.grey.shade50,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '📊 خلاصه نتایج ایستگاه‌های خط تولید در این تاریخ:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    ...stationList.map((st) {
                                      bool isStationOk =
                                          st['overall_status'] == 'OK';
                                      List details = st['details'] ?? [];
                                      return Card(
                                        color: isStationOk
                                            ? Colors.green.shade50
                                            : Colors.red.shade50,
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: ListTile(
                                          dense: true,
                                          title: Text(
                                            'ایستگاه: ${st['station_code']} (بازرس: ${st['auditor_name']} - شیفت: ${st['shift']})',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: details.map((det) {
                                              return Text(
                                                '• ${det['item_label'] ?? det['item_key']}: ${det['measured_value'] ?? det['visual_status']} [${det['status']}]',
                                                style: TextStyle(
                                                  color: det['status'] == 'OK'
                                                      ? Colors.green.shade900
                                                      : Colors.red.shade900,
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Chip(
                                                label: Text(
                                                  st['overall_status'],
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                backgroundColor: isStationOk
                                                    ? Colors.green
                                                    : const Color(0xFFE30613),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.edit,
                                                  color: Colors.blue,
                                                  size: 18,
                                                ),
                                                onPressed: () =>
                                                    _showEditDialog(st),
                                                tooltip: 'ویرایش بازرس/شیفت',
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete,
                                                  color: Color(0xFFE30613),
                                                  size: 18,
                                                ),
                                                onPressed: () =>
                                                    _confirmDelete(st['id']),
                                                tooltip: 'حذف این ایستگاه',
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      elevation: 2,
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}