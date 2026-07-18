import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class ManagementDashboardScreen extends StatefulWidget {
  const ManagementDashboardScreen({super.key});

  @override
  State<ManagementDashboardScreen> createState() => _ManagementDashboardScreenState();
}

class _ManagementDashboardScreenState extends State<ManagementDashboardScreen> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  String? _selectedBatchId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Management Dashboard'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _selectMonth,
            tooltip: 'Select Month',
          ),
        ],
      ),
      body: Container(
        color: Colors.grey.shade100,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOverallKPIs(),
              const SizedBox(height: 20),
              _buildBatchWisePerformance(),
              const SizedBox(height: 20),
              _buildMonthlyTrend(),
              const SizedBox(height: 20),
              _buildCriticalAlerts(),
            ],
          ),
        ),
      ),
    );
  }

  // 📊 Overall KPIs Section
  Widget _buildOverallKPIs() {
    return FutureBuilder<QuerySnapshot>(
      future: _getMonthlyData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No data available', style: TextStyle(color: Colors.grey)));
        }

        final docs = snapshot.data!.docs;
        int totalPresent = 0;
        int totalAbsent = 0;
        int totalOff = 0;
        int totalHoliday = 0;
        Set<String> uniqueStudents = {};
        List<Map<String, dynamic>> absentStudentsList = [];

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? '').toLowerCase();
          final studentId = data['studentId'] ?? '';
          
          if (studentId.isNotEmpty) uniqueStudents.add(studentId);
          
          if (status == 'present') {
            totalPresent++;
          } else if (status == 'absent') {
            totalAbsent++;
            absentStudentsList.add({
              'name': data['studentName'] ?? 'Unknown',
              'roll': data['rollNumber'] ?? 'N/A',
              'batch': data['batchName'] ?? 'Unknown',
              'id': studentId,
              'date': data['date'] ?? '',
            });
          } else if (status == 'off') {
            totalOff++;
          } else if (status == 'holiday') {
            totalHoliday++;
          }
        }

        int workingDays = totalPresent + totalAbsent;
        double attendancePercentage = workingDays > 0 ? ((totalPresent.toDouble() / workingDays.toDouble()) * 100.0) : 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Overall Performance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildKPICard('Total Students', '${uniqueStudents.length}', Colors.blue, Icons.people)),
                const SizedBox(width: 12),
                Expanded(child: _buildKPICard('Present', '$totalPresent', Colors.green, Icons.check_circle)),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _showOverallAbsentStudentsDetails(absentStudentsList),
                    borderRadius: BorderRadius.circular(12),
                    child: _buildKPICard('Absent', '$totalAbsent', Colors.red, Icons.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _buildKPICard('Attendance %', '${attendancePercentage.toStringAsFixed(1)}%', 
                    attendancePercentage >= 75.0 ? Colors.green : attendancePercentage >= 50.0 ? Colors.orange : Colors.red, 
                    Icons.analytics)),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Attendance Distribution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 250,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 50,
                        sections: [
                          if (totalPresent > 0) PieChartSectionData(
                            value: totalPresent.toDouble(),
                            title: 'Present\n${((totalPresent.toDouble() / (totalPresent + totalAbsent).toDouble()) * 100.0).toStringAsFixed(0)}%',
                            color: Colors.green,
                            radius: 70,
                            titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          if (totalAbsent > 0) PieChartSectionData(
                            value: totalAbsent.toDouble(),
                            title: 'Absent\n${((totalAbsent.toDouble() / (totalPresent + totalAbsent).toDouble()) * 100.0).toStringAsFixed(0)}%',
                            color: Colors.red,
                            radius: 70,
                            titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          if (totalOff > 0) PieChartSectionData(
                            value: totalOff.toDouble(),
                            title: 'Off',
                            color: Colors.blue,
                            radius: 60,
                            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          if (totalHoliday > 0) PieChartSectionData(
                            value: totalHoliday.toDouble(),
                            title: 'Holiday',
                            color: Colors.orange,
                            radius: 60,
                            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKPICard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // 📈 Batch-wise Performance
  Widget _buildBatchWisePerformance() {
    return FutureBuilder<QuerySnapshot>(
      future: _getMonthlyData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox();
        }

        final docs = snapshot.data!.docs;
        Map<String, Map<String, int>> batchData = {};

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final batchName = data['batchName'] ?? 'Unknown';
          final status = (data['status'] ?? '').toLowerCase();
          
          if (!batchData.containsKey(batchName)) {
            batchData[batchName] = {'present': 0, 'absent': 0, 'total': 0};
          }
          
          if (status == 'present') {
            batchData[batchName]!['present'] = (batchData[batchName]!['present'] ?? 0) + 1;
          } else if (status == 'absent') {
            batchData[batchName]!['absent'] = (batchData[batchName]!['absent'] ?? 0) + 1;
          }
          batchData[batchName]!['total'] = (batchData[batchName]!['total'] ?? 0) + 1;
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Batch-wise Performance',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showBatchDetails(batchData),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('View Details'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.indigo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 250,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 100.0,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final batchName = batchData.keys.elementAt(group.x.toInt());
                          final present = batchData[batchName]!['present'] ?? 0;
                          final absent = batchData[batchName]!['absent'] ?? 0;
                          final total = batchData[batchName]!['total'] ?? 0;
                          final percentage = total > 0 ? ((present.toDouble() / total.toDouble()) * 100.0) : 0.0;
                          
                          return BarTooltipItem(
                            '$batchName\n'
                            'Total: $total\n'
                            'Present: $present\n'
                            'Absent: $absent\n'
                            'Attendance: ${percentage.toStringAsFixed(1)}%',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= batchData.length) {
                              return const SizedBox.shrink();
                            }
                            final batchName = batchData.keys.elementAt(value.toInt());
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                batchName.length > 8 
                                    ? '${batchName.substring(0, 8)}...' 
                                    : batchName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black, // 🆕 PURE BLACK
                                  fontWeight: FontWeight.bold, // 🆕 BOLD
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '${value.toInt()}%',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black, // 🆕 PURE BLACK
                                fontWeight: FontWeight.bold, // 🆕 BOLD
                              ),
                            );
                          },
                          reservedSize: 40, // 🆕 INCREASED TO PREVENT CUTOFF
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: batchData.entries.toList().asMap().entries.map((entry) {
                      final index = entry.key;
                      final batchDataEntry = entry.value;
                      final present = batchDataEntry.value['present'] ?? 0;
                      final absent = batchDataEntry.value['absent'] ?? 0;
                      final total = present + absent;
                      final percentage = total > 0 ? ((present.toDouble() / total.toDouble()) * 100.0) : 0.0;
                      
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: percentage,
                            gradient: LinearGradient(
                              colors: percentage >= 75.0 
                                  ? [Colors.green.shade400, Colors.green.shade600]
                                  : percentage >= 50.0
                                      ? [Colors.orange.shade400, Colors.orange.shade600]
                                      : [Colors.red.shade400, Colors.red.shade600],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            width: 20,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(6),
                              topRight: Radius.circular(6),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

   // 📅 Monthly Trend
  Widget _buildMonthlyTrend() {
    return FutureBuilder<QuerySnapshot>(
      future: _getMonthlyTrendData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Monthly Attendance Trend',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'No historical data available',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        Map<String, Map<String, int>> monthlyData = {};
        final docs = snapshot.data!.docs;

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final date = data['date'] ?? '';
          final status = (data['status'] ?? '').toLowerCase();
          
          if (date.length >= 7) {
            final month = date.substring(0, 7);
            
            if (!monthlyData.containsKey(month)) {
              monthlyData[month] = {'present': 0, 'absent': 0, 'total': 0};
            }
            
            if (status == 'present') {
              monthlyData[month]!['present'] = (monthlyData[month]!['present'] ?? 0) + 1;
            } else if (status == 'absent') {
              monthlyData[month]!['absent'] = (monthlyData[month]!['absent'] ?? 0) + 1;
            }
            monthlyData[month]!['total'] = (monthlyData[month]!['total'] ?? 0) + 1;
          }
        }

        final sortedMonths = monthlyData.keys.toList()..sort();
        
        List<FlSpot> attendanceSpots = [];
        for (int i = 0; i < sortedMonths.length; i++) {
          final month = sortedMonths[i];
          final present = monthlyData[month]!['present'] ?? 0;
          final total = monthlyData[month]!['total'] ?? 1;
          final percentage = (present.toDouble() / total.toDouble()) * 100.0;
          
          attendanceSpots.add(FlSpot(i.toDouble(), percentage));
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Monthly Attendance Trend',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 250,
                child: LineChart(
                  LineChartData(
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (spot) => Colors.blueGrey.shade800, // ✅ CORRECT PARAMETER
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            return LineTooltipItem(
                              '${spot.y.toStringAsFixed(1)}%',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      horizontalInterval: 20.0,
                      verticalInterval: 1.0,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey.shade300,
                          strokeWidth: 1,
                        );
                      },
                      getDrawingVerticalLine: (value) {
                        return FlLine(
                          color: Colors.grey.shade300,
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1.0,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= sortedMonths.length) {
                              return const SizedBox.shrink();
                            }
                            final month = sortedMonths[value.toInt()];
                            final monthDate = DateTime.parse('$month-01');
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                '${_getMonthAbbreviation(monthDate.month)} ${monthDate.year.toString().substring(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black, 
                                  fontWeight: FontWeight.bold, 
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 20.0,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '${value.toInt()}%',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black, 
                                fontWeight: FontWeight.bold, 
                              ),
                            );
                          },
                          reservedSize: 45,
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: attendanceSpots,
                        isCurved: true,
                        color: Colors.indigo,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: Colors.white,
                              strokeWidth: 2,
                              strokeColor: Colors.indigo,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.indigo.withOpacity(0.1),
                        ),
                      ),
                    ],
                    minY: 0.0,
                    maxY: 100.0,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  // ⚠️ Critical Alerts
  Widget _buildCriticalAlerts() {
    return FutureBuilder<QuerySnapshot>(
      future: _getMonthlyData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();

        final docs = snapshot.data!.docs;
        Map<String, Map<String, dynamic>> batchStats = {};

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final batchName = data['batchName'] ?? 'Unknown';
          final status = (data['status'] ?? '').toLowerCase();
          final studentId = data['studentId'] ?? '';
          final studentName = data['studentName'] ?? '';
          final rollNumber = data['rollNumber'] ?? '';
          
          if (!batchStats.containsKey(batchName)) {
            batchStats[batchName] = {'present': 0, 'absent': 0, 'total': 0, 'absentStudents': <Map<String, String>>[]};
          }
          
          if (status == 'present') {
            batchStats[batchName]!['present'] = (batchStats[batchName]!['present'] as int) + 1;
          } else if (status == 'absent') {
            batchStats[batchName]!['absent'] = (batchStats[batchName]!['absent'] as int) + 1;
            if (studentId.isNotEmpty) {
              (batchStats[batchName]!['absentStudents'] as List<Map<String, String>>).add({
                'name': studentName,
                'roll': rollNumber,
                'id': studentId,
              });
            }
          }
          batchStats[batchName]!['total'] = (batchStats[batchName]!['total'] as int) + 1;
        }

        final lowAttendanceBatches = batchStats.entries.where((entry) {
          final present = entry.value['present'] as int;
          final absent = entry.value['absent'] as int;
          final total = present + absent;
          final percentage = total > 0 ? ((present.toDouble() / total.toDouble()) * 100.0) : 0.0;
          return percentage < 75.0;
        }).toList();

        if (lowAttendanceBatches.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.green.shade200)),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700, size: 32),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('All Batches Performing Well!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                    Text('All batches have attendance above 75%', style: TextStyle(color: Colors.green.shade700)),
                  ],
                )),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.shade200)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning, color: Colors.red.shade700, size: 32),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('⚠️ Attention Required', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                      Text('${lowAttendanceBatches.length} batch(es) with low attendance', style: TextStyle(color: Colors.red.shade700)),
                    ],
                  )),
                ],
              ),
              const SizedBox(height: 12),
              ...lowAttendanceBatches.map((entry) {
                final batchName = entry.key;
                final present = entry.value['present'] as int;
                final absent = entry.value['absent'] as int;
                final total = present + absent;
                final percentage = total > 0 ? ((present.toDouble() / total.toDouble()) * 100.0) : 0.0;
                
                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(batchName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('${present}P / ${absent}A', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: percentage < 50.0 ? Colors.red.shade100 : Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: percentage < 50.0 ? Colors.red : Colors.orange),
                        ),
                        child: Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: percentage < 50.0 ? Colors.red.shade700 : Colors.orange.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showAbsentStudentsDetails(batchStats),
                  icon: const Icon(Icons.people_outline),
                  label: const Text('View Absent Students'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // HELPER METHODS & MODALS
  // ==========================================

  Future<void> _selectMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_selectedYear, _selectedMonth),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = picked.month;
        _selectedYear = picked.year;
      });
    }
  }

  Future<QuerySnapshot> _getMonthlyData() async {
    final monthStr = _selectedMonth.toString().padLeft(2, '0');
    final yearStr = _selectedYear.toString();
    final startDate = '$yearStr-$monthStr-01';
    final endDate = '$yearStr-$monthStr-31';
    
    return await FirebaseFirestore.instance
        .collection('student_attendance')
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThanOrEqualTo: endDate)
        .get();
  }

  Future<QuerySnapshot> _getMonthlyTrendData() async {
    final now = DateTime(_selectedYear, _selectedMonth);
    final sixMonthsAgo = DateTime(now.year, now.month - 5, 1);
    
    final startDate = '${sixMonthsAgo.year}-${sixMonthsAgo.month.toString().padLeft(2, '0')}-01';
    final endDate = '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}-31';
    
    return await FirebaseFirestore.instance
        .collection('student_attendance')
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThanOrEqualTo: endDate)
        .get();
  }

  String _getMonthAbbreviation(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  void _showBatchDetails(Map<String, Map<String, int>> batchData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Batch-wise Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: batchData.length,
                  itemBuilder: (context, index) {
                    final batchName = batchData.keys.elementAt(index);
                    final data = batchData[batchName]!;
                    final present = data['present'] ?? 0;
                    final absent = data['absent'] ?? 0;
                    final total = data['total'] ?? 0;
                    final percentage = total > 0 ? ((present.toDouble() / total.toDouble()) * 100.0) : 0.0;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: percentage >= 75.0 ? Colors.green : percentage >= 50.0 ? Colors.orange : Colors.red,
                          child: Text('${percentage.toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(batchName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Present: $present | Absent: $absent | Total: $total'),
                        trailing: Text('${percentage.toStringAsFixed(1)}%', 
                            style: TextStyle(
                              color: percentage >= 75.0 ? Colors.green : percentage >= 50.0 ? Colors.orange : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            )),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAbsentStudentsDetails(Map<String, Map<String, dynamic>> batchStats) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Absent Students', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: batchStats.length,
                  itemBuilder: (context, index) {
                    final batchName = batchStats.keys.elementAt(index);
                    final absentStudents = batchStats[batchName]!['absentStudents'] as List<Map<String, String>>;
                    
                    if (absentStudents.isEmpty) return const SizedBox();
                    
                    return ExpansionTile(
                      leading: CircleAvatar(backgroundColor: Colors.red, child: Text('${absentStudents.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      title: Text(batchName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${absentStudents.length} absent student(s)'),
                      children: absentStudents.map((student) {
                        return ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.red.shade100, child: Text(student['name']![0].toUpperCase(), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                          title: Text(student['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Roll: ${student['roll']}'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                            child: const Text('ABSENT', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showOverallAbsentStudentsDetails(List<Map<String, dynamic>> absentStudents) {
    Map<String, List<Map<String, dynamic>>> groupedByBatch = {};
    for (var student in absentStudents) {
      final batch = student['batch'] ?? 'Unknown Batch';
      if (!groupedByBatch.containsKey(batch)) {
        groupedByBatch[batch] = [];
      }
      groupedByBatch[batch]!.add(student);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Overall Absent Students', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              Expanded(
                child: groupedByBatch.isEmpty 
                  ? const Center(child: Text('No absent students found for this period.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: groupedByBatch.length,
                      itemBuilder: (context, index) {
                        final batchName = groupedByBatch.keys.elementAt(index);
                        final students = groupedByBatch[batchName]!;
                        
                        return ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.red, 
                            child: Text('${students.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                          ),
                          title: Text(batchName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${students.length} absent record(s)'),
                          children: students.map((student) {
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.red.shade100, 
                                child: Text(
                                  (student['name'] ?? 'U')[0].toUpperCase(), 
                                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)
                                )
                              ),
                              title: Text(student['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Roll: ${student['roll']} • Date: ${student['date']}'),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2), 
                                  borderRadius: BorderRadius.circular(4)
                                ),
                                child: const Text('ABSENT', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}