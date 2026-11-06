import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/inspection_provider.dart';
import 'spec_management_screen.dart';
import 'inspection_form_screen.dart';
import 'inspection_report_screen.dart';
import 'qr_scanner_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 3; // پیش‌فرض تب داشبورد
  List _allReports = [];
  bool _isLoading = true;

  final List<Widget> _screens = [
    const SpecManagementScreen(),
    const InspectionFormScreen(),
    const InspectionReportScreen(),
    const SizedBox.shrink(), // جایگاه داشبورد
  ];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    try {
      final provider = Provider.of<InspectionProvider>(context, listen: false);
      final baseUrl = provider.baseUrl;
      final reportsRes = await http.get(Uri.parse('$baseUrl/inspections/report'));

      if (reportsRes.statusCode == 200) {
        setState(() {
          _allReports = json.decode(utf8.decode(reportsRes.bodyBytes));
        });
      }
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // دیالوگ گزارش نموداری و تحلیلی در داشبورد
  void _showChartAnalysisDialog() {
    Map<String, int> dateNgCounts = {};
    List detailedDefects = [];

    for (var item in _allReports) {
      if (item['overall_status'] == 'NG') {
        String rawDate = (item['created_at'] ?? item['inspection_date'] ?? '').toString();
        String date = rawDate.length >= 10 ? rawDate.substring(0, 10) : 'بدون تاریخ';
        
        dateNgCounts[date] = (dateNgCounts[date] ?? 0) + 1;

        List details = item['details'] ?? [];
        for (var det in details) {
          if (det['status'] == 'NG') {
            detailedDefects.add({
              'date': date,
              'station': item['station_code'] ?? 'ایستگاه نامشخص',
              'defect_name': det['item_label'] ?? det['item_key'] ?? 'عیب نامشخص',
            });
          }
        }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.bar_chart, color: Color(0xFFE30613)),
            SizedBox(width: 8),
            Text('گزارش نموداری و تحلیلی معیوبی‌ها', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('نمودار ستونی تعداد معیوبی‌ها بر اساس تاریخ (رو به بالا):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 12),
                dateNgCounts.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Center(child: Text('هیچ عیب (NG) ثبت‌شده‌ای وجود ندارد.', style: TextStyle(color: Colors.grey))),
                      )
                    : SizedBox(
                        height: 180,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: dateNgCounts.entries.map((entry) {
                            String date = entry.key;
                            int count = entry.value;
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFE30613))),
                                const SizedBox(height: 4),
                                Container(
                                  width: 36,
                                  height: (count * 25.0).clamp(25.0, 120.0),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE30613),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(date, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                const Divider(height: 24),
                const Text('نام عیب‌های ثبت‌شده و جزئیات:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                detailedDefects.isEmpty
                    ? const Text('جزئیاتی ثبت نشده است.', style: TextStyle(fontSize: 12, color: Colors.grey))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: detailedDefects.length,
                        itemBuilder: (context, index) {
                          final def = detailedDefects[index];
                          return Card(
                            color: Colors.red.shade50,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              dense: true,
                              title: Text('نام عیب: ${def['defect_name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              subtitle: Text('تاریخ: ${def['date']} | ایستگاه: ${def['station']}', style: const TextStyle(fontSize: 11)),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE30613)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('بستن', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedIndex != 3) {
      return Scaffold(
        body: _screens[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          selectedItemColor: const Color(0xFFE30613),
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          onTap: (index) {
            if (index == 3) {
              setState(() => _selectedIndex = 3);
              _fetchDashboardData();
            } else {
              setState(() => _selectedIndex = index);
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.settings_applications), label: 'تعریف استانداردها'),
            BottomNavigationBarItem(icon: Icon(Icons.assignment_add), label: 'ثبت بازرسی'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'گزارش‌ها'),
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'QC داشبورد'),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('داشبورد مدیریت کیفیت'),
        backgroundColor: const Color(0xFFE30613),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetchDashboardData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE30613), Color(0xFFB3000E)],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                          ],
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'سامانه هوشمند کنترل کیفیت و ممیزی',
                              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'استاندارد ISO 9001:2015 | خط تولید لوازم خانگی گلدایران',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'ماژول‌های مدیریت سامانه',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo.shade700,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onPressed: _showChartAnalysisDialog,
                            icon: const Icon(Icons.analytics, color: Colors.white, size: 18),
                            label: const Text('گزارش نموداری و تحلیلی', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.3,
                        children: [
                          _buildModuleCard(
                            title: 'ثبت فرم بازرسی',
                            subtitle: 'چک‌لیست تولید',
                            icon: Icons.assignment_add,
                            color: Colors.green.shade700,
                            onTap: () => setState(() => _selectedIndex = 1),
                          ),
                          _buildModuleCard(
                            title: 'تعریف استانداردها',
                            subtitle: 'مدیریت مشخصات ایستگاه‌ها',
                            icon: Icons.settings_applications,
                            color: Colors.blue.shade700,
                            onTap: () => setState(() => _selectedIndex = 0),
                          ),
                          _buildModuleCard(
                            title: 'اسکنر بارکد و QR',
                            subtitle: 'شناسایی بارکد محصول',
                            icon: Icons.qr_code_scanner,
                            color: Colors.purple.shade700,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const QrScannerScreen(),
                                ),
                              );
                            },
                          ),
                          _buildModuleCard(
                            title: 'گزارش‌های جامع و اکسل',
                            subtitle: 'خروجی اکسل و نمودارها',
                            icon: Icons.bar_chart,
                            color: Colors.orange.shade800,
                            onTap: () => setState(() => _selectedIndex = 2),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFFE30613),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 3) {
            _fetchDashboardData();
          } else {
            setState(() => _selectedIndex = index);
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.settings_applications), label: 'تعریف استانداردها'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_add), label: 'ثبت بازرسی'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'گزارش‌ها'),
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'QC داشبورد'),
        ],
      ),
    );
  }

  Widget _buildModuleCard({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 6),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 2),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}