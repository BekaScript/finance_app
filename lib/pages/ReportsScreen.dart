import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:personal_finance/database/database_helper.dart';
import 'package:personal_finance/utils/currency_utils.dart';
import 'package:personal_finance/services/language_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final LanguageService _languageService = LanguageService();
  late Future<Map<String, dynamic>> _reportsFuture;
  List<String> selectedCategories = [];
  List<String> allCategories = []; // To hold all available categories
  DateTime? selectedStartDate;
  DateTime? selectedEndDate;
  String selectedType = 'expense'; // Default to 'expense'
  String _currencySymbol = '\$';

  @override
  void initState() {
    super.initState();
    _loadCurrency();
    _reportsFuture = _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload currency when returning to this screen
    _loadCurrency();
  }

  Future<void> _loadCurrency() async {
    final currency = await _dbHelper.getCurrency();
    if (mounted) {
      setState(() {
        _currencySymbol = getCurrencySymbol(currency);
        // Refresh the data to update all currency displays
        _reportsFuture = _loadData();
      });
    }
  }

  Future<Map<String, dynamic>> _loadData() async {
    try {
      final db = await _dbHelper.database;

      // Set default date range if not selected
      final now = DateTime.now();
      final defaultStartDate = DateTime(now.year, now.month - 2, 1); // Last 3 months by default
      final defaultEndDate = DateTime(now.year, now.month + 1, 0); // Until end of current month

      // Build the query based on filters
      String whereClause = "type = ? AND date BETWEEN ? AND ?";
      List<dynamic> whereArgs = [
        selectedType,
        (selectedStartDate ?? defaultStartDate).toIso8601String().substring(0, 10),
        (selectedEndDate ?? defaultEndDate).toIso8601String().substring(0, 10),
      ];

      if (selectedCategories.isNotEmpty) {
        whereClause +=
            " AND category IN (${List.filled(selectedCategories.length, '?').join(',')})";
        whereArgs.addAll(selectedCategories);
      }

      final transactions = await db.query(
        'transactions',
        where: whereClause, 
        whereArgs: whereArgs,
        orderBy: 'date DESC', // Add ordering
      );

      Map<String, double> categoryData = {};
      Map<String, double> monthlyData = {};

      // Collecting all unique categories for filtering
      Set<String> uniqueCategories = {}; // Using Set for better performance
      
      for (var transaction in transactions) {
        String category = transaction['category'] as String;
        double amount = (transaction['amount'] as num).toDouble();
        String dateString = transaction['date'] as String;

        // Add category to unique categories
        uniqueCategories.add(category);

        // Process data for charts
        if (dateString.length >= 7) {
          String month = dateString.substring(0, 7);
          if (selectedCategories.isEmpty || selectedCategories.contains(category)) {
            categoryData[category] = (categoryData[category] ?? 0) + amount;
            monthlyData[month] = (monthlyData[month] ?? 0) + amount;
          }
        }
      }

      // Update allCategories list
      allCategories = uniqueCategories.toList();

      return {
        "categorySpending": categoryData,
        "monthlySpending": monthlyData,
      };
    } catch (e) {
      throw Exception("Failed to load data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _languageService.translate('reports'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueAccent, Colors.purpleAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _reportsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                "Failed to load data: ${snapshot.error}",
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                "No data available",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          final categorySpending =
              snapshot.data!["categorySpending"] as Map<String, double>;
          final monthlySpending =
              snapshot.data!["monthlySpending"] as Map<String, double>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFilters(),
                const SizedBox(height: 20),
                _buildChartCard(
                  title: _languageService.translate('categoryWiseSpending'),
                  child: categorySpending.isEmpty
                      ? _buildNoDataWidget()
                      : Column(
                          children: [
                            _buildLegend(categorySpending),
                            const SizedBox(height: 20),
                            Container(
                              height: 250,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                              child: PieChart(
                                PieChartData(
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 35,
                                  sections: categorySpending.entries.map((entry) {
                                    final color = _getChartColor(entry.key);
                                    return PieChartSectionData(
                                      value: entry.value,
                                      title: '',
                                      radius: 60,
                                      titleStyle: const TextStyle(fontSize: 0),
                                      color: color,
                                      badgeWidget: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border.all(color: color, width: 1),
                                          borderRadius: BorderRadius.circular(4),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.1),
                                              spreadRadius: 1,
                                              blurRadius: 2,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          '${_languageService.translate(entry.key)}\n$_currencySymbol${entry.value.toStringAsFixed(0)}',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      badgePositionPercentageOffset: 1.5,
                                      showTitle: false,
                                    );
                                  }).toList(),
                                  pieTouchData: PieTouchData(enabled: false),
                                  borderData: FlBorderData(show: false),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                ),
                const SizedBox(height: 20),
                _buildChartCard(
                  title: _languageService.translate('monthlySpendingTrends'),
                  child: monthlySpending.isEmpty
                      ? _buildNoDataWidget()
                      : SizedBox(
                          height: 250,
                          child: BarChart(
                            BarChartData(
                              barGroups: monthlySpending.entries.map((entry) {
                                return BarChartGroupData(
                                  x: int.parse(entry.key.split('-')[1]),
                                  barRods: [
                                    BarChartRodData(
                                      toY: entry.value,
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.blueAccent,
                                          Colors.purpleAccent,
                                        ],
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                      ),
                                      width: 16,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ],
                                );
                              }).toList(),
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        _getMonthLabel(value.toInt()),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black87,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 60,
                                    interval: null,
                                    getTitlesWidget: (value, meta) {
                                      double maxValue = monthlySpending.values.reduce((max, value) => max > value ? max : value);
                                      double interval = _calculateInterval(maxValue);
                                      
                                      if (value % interval != 0) return const SizedBox.shrink();
                                      
                                      String text = '';
                                      if (value >= 1000000) {
                                        text = '${_currencySymbol}${(value/1000000).toStringAsFixed(1)}M';
                                      } else if (value >= 1000) {
                                        text = '${_currencySymbol}${(value/1000).toStringAsFixed(1)}K';
                                      } else {
                                        text = '${_currencySymbol}${value.toInt()}';
                                      }
                                      return Text(
                                        text,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                topTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      double maxValue = monthlySpending.values.reduce((max, value) => max > value ? max : value);
                                      double interval = _calculateInterval(maxValue);
                                      
                                      if (value % interval != 0) return const SizedBox.shrink();
                                      
                                      String text = '';
                                      if (value >= 1000000) {
                                        text = '${_currencySymbol}${(value/1000000).toStringAsFixed(1)}M';
                                      } else if (value >= 1000) {
                                        text = '${_currencySymbol}${(value/1000).toStringAsFixed(1)}K';
                                      } else {
                                        text = '${_currencySymbol}${value.toInt()}';
                                      }
                                      return Text(
                                        text,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                rightTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: _calculateInterval(
                                  monthlySpending.values.reduce((max, value) => max > value ? max : value)
                                ),
                                getDrawingHorizontalLine: (value) {
                                  return FlLine(
                                    color: Colors.grey.withOpacity(0.2),
                                    strokeWidth: 1,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Build the filter section
  Widget _buildFilters() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _languageService.translate('filters'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            _buildTypeFilter(),
            const SizedBox(height: 12),
            _buildDateRangeFilter(),
            const SizedBox(height: 12),
            _buildCategoryFilter(),
          ],
        ),
      ),
    );
  }

  // Type filter (expense/income)
  Widget _buildTypeFilter() {
    return DropdownButtonFormField<String>(
      value: selectedType,
      decoration: InputDecoration(
        labelText: _languageService.translate('type'),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      items: [
        DropdownMenuItem(value: 'expense', child: Text(_languageService.translate('expenses'))),
        DropdownMenuItem(value: 'income', child: Text(_languageService.translate('income'))),
      ],
      onChanged: (value) {
        setState(() {
          selectedType = value!;
          _reportsFuture = _loadData(); // Refresh data
        });
      },
    );
  }

  // Date range filter
  Widget _buildDateRangeFilter() {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: selectedStartDate ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() {
                  selectedStartDate = date;
                  _reportsFuture = _loadData(); // Refresh data
                });
              }
            },
            child: Text(
              selectedStartDate == null
                  ? _languageService.translate('selectStartDate')
                  : 'Start: ${selectedStartDate!.toLocal().toString().split(' ')[0]}',
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextButton(
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: selectedEndDate ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() {
                  selectedEndDate = date;
                  _reportsFuture = _loadData(); // Refresh data
                });
              }
            },
            child: Text(
              selectedEndDate == null
                  ? _languageService.translate('selectEndDate')
                  : 'End: ${selectedEndDate!.toLocal().toString().split(' ')[0]}',
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ),
      ],
    );
  }

  // Category filter
  Widget _buildCategoryFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _languageService.translate('filterByCategory'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: allCategories.map((category) {
            return FilterChip(
              label: Text(_languageService.translate(category)),
              selected: selectedCategories.contains(category),
              onSelected: (isSelected) {
                setState(() {
                  if (isSelected) {
                    selectedCategories.add(category);
                  } else {
                    selectedCategories.remove(category);
                  }
                  _reportsFuture = _loadData();
                });
              },
              selectedColor: Colors.blueAccent,
              backgroundColor: Colors.grey[200],
              labelStyle: TextStyle(
                color: selectedCategories.contains(category)
                    ? Colors.white
                    : Colors.black87,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Build a card for charts
  Widget _buildChartCard({required String title, required Widget child}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  // Widget to display when no data is available
  Widget _buildNoDataWidget() {
    return const Center(
      child: Text(
        "No data available for the selected filters",
        style: TextStyle(color: Colors.grey, fontSize: 16),
      ),
    );
  }

  // Build a legend for the pie chart
  Widget _buildLegend(Map<String, double> data) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        spacing: 16, // Increased spacing between items
        runSpacing: 8, // Added spacing between rows
        alignment: WrapAlignment.center, // Center the legend items
        children: data.entries.map((entry) {
          final color = _getChartColor(entry.key);
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _languageService.translate(entry.key),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // Get month label for bar chart
  String _getMonthLabel(int month) {
    return DateTime(2023, month).toString().split(' ')[0].substring(5, 7);
  }

  // Get a unique color for each category
  Color _getChartColor(String category) {
    // Map of distinct colors for each category
    final Map<String, Color> categoryColors = {
      'Food': const Color(0xFF2196F3),      // Blue
      'Transport': const Color(0xFFF44336),  // Red
      'Shopping': const Color(0xFF4CAF50),   // Green
      'Bills': const Color(0xFFFF9800),      // Orange
      'Others': const Color(0xFF9C27B0),     // Purple
    };

    return categoryColors[category] ?? Colors.grey; // Default to grey if category not found
  }

  Color _getRandomColor() {
    // Implement your logic to generate a random color
    // This is a placeholder and should be replaced with actual implementation
    return Colors.blueAccent;
  }

  double _calculateInterval(double maxValue) {
    if (maxValue >= 1000000) {
      return 1000000; // Show in millions
    } else if (maxValue >= 100000) {
      return 20000; // Show in 20K intervals
    } else if (maxValue >= 10000) {
      return 2000; // Show in 2K intervals
    } else if (maxValue >= 1000) {
      return 500; // Show in 500 intervals
    } else {
      return 100; // Show in 100 intervals
    }
  }
}
