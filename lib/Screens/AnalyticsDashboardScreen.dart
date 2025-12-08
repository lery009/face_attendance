import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../api/api_service.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  final ApiService apiService = ApiService();

  Map<String, dynamic> analyticsData = {};
  Map<String, dynamic> trendsData = {};
  List<dynamic> departmentStats = [];
  List<dynamic> topPerformers = [];

  bool isLoading = true;
  int selectedDays = 7;

  @override
  void initState() {
    super.initState();
    loadAnalytics();
  }

  Future<void> loadAnalytics() async {
    setState(() => isLoading = true);

    try {
      final overview = await apiService.getAnalyticsOverview();
      final trends = await apiService.getAttendanceTrends(days: selectedDays);
      final deptStats = await apiService.getDepartmentStats();
      final performance = await apiService.getEmployeePerformance(days: 30);

      setState(() {
        if (overview['success'] == true) {
          analyticsData = overview['data'] ?? {};
        }
        if (trends['success'] == true) {
          trendsData = trends;
        }
        if (deptStats['success'] == true) {
          departmentStats = deptStats['departments'] ?? [];
        }
        if (performance['success'] == true) {
          topPerformers = performance['top_performers'] ?? [];
        }
        isLoading = false;
      });
    } catch (e) {
      print('Analytics error: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadAnalytics,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadAnalytics,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      'Real-time Analytics',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Today\'s attendance overview and trends',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Today's Stats Cards
                    _buildTodayStatsCards(),
                    const SizedBox(height: 24),

                    // Status Breakdown Pie Chart
                    _buildStatusBreakdown(),
                    const SizedBox(height: 24),

                    // Attendance Trend Line Chart
                    _buildAttendanceTrend(),
                    const SizedBox(height: 24),

                    // Hourly Distribution
                    _buildHourlyDistribution(),
                    const SizedBox(height: 24),

                    // Department Statistics
                    _buildDepartmentStats(),
                    const SizedBox(height: 24),

                    // Top Performers
                    _buildTopPerformers(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTodayStatsCards() {
    final today = analyticsData['today'] ?? {};
    final comparison = analyticsData['comparison'] ?? {};

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Check-ins',
                today['total_check_ins']?.toString() ?? '0',
                Icons.fact_check,
                const Color(0xFF10B981),
                change: comparison['change'],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Attendance Rate',
                '${today['attendance_rate']?.toString() ?? '0'}%',
                Icons.pie_chart,
                const Color(0xFF3B82F6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'On Time',
                today['on_time']?.toString() ?? '0',
                Icons.check_circle,
                const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Late',
                today['late']?.toString() ?? '0',
                Icons.access_time,
                const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Half Day',
                today['half_day']?.toString() ?? '0',
                Icons.schedule,
                const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, {int? change}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              if (change != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: change >= 0 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${change >= 0 ? '+' : ''}$change',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: change >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBreakdown() {
    final today = analyticsData['today'] ?? {};
    final onTime = today['on_time'] ?? 0;
    final late = today['late'] ?? 0;
    final halfDay = today['half_day'] ?? 0;
    final total = onTime + late + halfDay;

    if (total == 0) {
      return _buildChartCard('Status Breakdown', const Center(child: Text('No data available')));
    }

    return _buildChartCard(
      'Status Breakdown',
      Row(
        children: [
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: onTime.toDouble(),
                      title: '${(onTime / total * 100).toInt()}%',
                      color: const Color(0xFF10B981),
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      value: late.toDouble(),
                      title: '${(late / total * 100).toInt()}%',
                      color: const Color(0xFFF59E0B),
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      value: halfDay.toDouble(),
                      title: '${(halfDay / total * 100).toInt()}%',
                      color: const Color(0xFFEF4444),
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 0,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLegendItem('On Time', const Color(0xFF10B981), onTime),
                const SizedBox(height: 8),
                _buildLegendItem('Late', const Color(0xFFF59E0B), late),
                const SizedBox(height: 8),
                _buildLegendItem('Half Day', const Color(0xFFEF4444), halfDay),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, int count) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
        const Spacer(),
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceTrend() {
    final trends = trendsData['trends'] as List? ?? [];

    if (trends.isEmpty) {
      return _buildChartCard('Attendance Trend', const Center(child: Text('No data available')));
    }

    return _buildChartCard(
      'Attendance Trend (Last $selectedDays Days)',
      Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildDaysButton(7),
              const SizedBox(width: 8),
              _buildDaysButton(14),
              const SizedBox(width: 8),
              _buildDaysButton(30),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey[300],
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: trends.length > 14 ? 5.0 : 1.0,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < trends.length) {
                          return Text(
                            trends[index]['day_name'] ?? '',
                            style: const TextStyle(fontSize: 10),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (trends.length - 1).toDouble(),
                minY: 0,
                maxY: (trends.map((e) => e['total'] as int).reduce((a, b) => a > b ? a : b) * 1.2),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      trends.length,
                      (index) => FlSpot(
                        index.toDouble(),
                        (trends[index]['total'] as int).toDouble(),
                      ),
                    ),
                    isCurved: true,
                    color: const Color(0xFF3B82F6),
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysButton(int days) {
    final isSelected = selectedDays == days;
    return InkWell(
      onTap: () async {
        setState(() {
          selectedDays = days;
          isLoading = true;
        });
        final trends = await apiService.getAttendanceTrends(days: days);
        setState(() {
          if (trends['success'] == true) {
            trendsData = trends;
          }
          isLoading = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A8A) : Colors.grey[200],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '${days}D',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildHourlyDistribution() {
    final hourlyData = (analyticsData['trends']?['hourly'] as List?) ?? [];

    if (hourlyData.isEmpty) {
      return _buildChartCard('Hourly Distribution', const Center(child: Text('No data available')));
    }

    return _buildChartCard(
      'Today\'s Hourly Distribution',
      SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 1,
              getDrawingHorizontalLine: (value) => FlLine(
                color: Colors.grey[300],
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) => Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 2,
                  getTitlesWidget: (value, meta) {
                    final hour = value.toInt();
                    if (hour % 2 == 0) {
                      return Text(
                        '${hour}h',
                        style: const TextStyle(fontSize: 10),
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            barGroups: hourlyData.map((data) {
              final hour = data['hour'] as int;
              final count = data['count'] as int;
              return BarChartGroupData(
                x: hour,
                barRods: [
                  BarChartRodData(
                    toY: count.toDouble(),
                    color: const Color(0xFF10B981),
                    width: 12,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentStats() {
    if (departmentStats.isEmpty) {
      return _buildChartCard('Department Statistics', const Center(child: Text('No data available')));
    }

    return _buildChartCard(
      'Department Statistics',
      ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: departmentStats.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final dept = departmentStats[index];
          final rate = dept['attendance_rate'] ?? 0.0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dept['department'] ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${rate}%',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: rate / 100,
                  backgroundColor: Colors.grey[200],
                  color: rate >= 75
                      ? Colors.green
                      : rate >= 50
                          ? Colors.orange
                          : Colors.red,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${dept['present_today']} / ${dept['total_employees']} present',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopPerformers() {
    if (topPerformers.isEmpty) {
      return _buildChartCard('Top Performers', const Center(child: Text('No data available')));
    }

    return _buildChartCard(
      'Top Performers (Last 30 Days)',
      ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: topPerformers.length,
        separatorBuilder: (_, __) => Divider(color: Colors.grey[200]),
        itemBuilder: (context, index) {
          final performer = topPerformers[index];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: index < 3
                  ? [Colors.amber, Colors.grey, Colors.brown][index]
                  : const Color(0xFF1E3A8A),
              child: Text(
                '${index + 1}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              performer['name'] ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              performer['department'] ?? 'N/A',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${performer['days_present']} days',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${performer['punctuality_rate']}% punctual',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChartCard(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
