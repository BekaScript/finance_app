import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:personal_finance/database/database_helper.dart';
import 'package:personal_finance/utils/currency_utils.dart';
import 'package:personal_finance/services/language_service.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final LanguageService _languageService = LanguageService();
  late Future<Map<String, dynamic>> _reportsFuture;
  ChartType _chartType = ChartType.pie;
  String selectedType = 'expense';
  String _currencySymbol = '₹';
  DateTime? selectedStartDate;
  DateTime? selectedEndDate;

  @override
  void initState() {
    super.initState();
    _loadCurrency();

    // Set default date range
    final now = DateTime.now();
    selectedStartDate = DateTime(now.year, now.month, 1); // Start of month
    selectedEndDate = DateTime(now.year, now.month + 1, 0); // End of month

    _reportsFuture = _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadCurrency();
  }

  Future<void> _loadCurrency() async {
    final currency = await _dbHelper.getCurrency();
    if (mounted) {
      setState(() {
        _currencySymbol = getCurrencySymbol(currency);
        _reportsFuture = _loadData();
      });
    }
  }

  Future<Map<String, dynamic>> _loadData() async {
    try {
      final db = await _dbHelper.database;
      
      // Ensure dates are initialized if null
      final now = DateTime.now();
      final start = selectedStartDate ?? DateTime(now.year, now.month, 1);
      final end = selectedEndDate ?? DateTime(now.year, now.month + 1, 0);

      // First load total income and expenses for the period
      final incomeTotal = await db.rawQuery('''
        SELECT COALESCE(SUM(amount), 0) as total,
               date,
               COALESCE(SUM(amount), 0) as daily_total
        FROM transactions 
        WHERE type = 'income' 
        AND date BETWEEN ? AND ?
        GROUP BY date
      ''', [
        start.toIso8601String().substring(0, 10),
        end.toIso8601String().substring(0, 10),
      ]);

      final expenseTotal = await db.rawQuery('''
        SELECT COALESCE(SUM(amount), 0) as total,
               date,
               COALESCE(SUM(amount), 0) as daily_total
        FROM transactions 
        WHERE type = 'expense' 
        AND date BETWEEN ? AND ?
        GROUP BY date
      ''', [
        start.toIso8601String().substring(0, 10),
        end.toIso8601String().substring(0, 10),
      ]);

      // Process daily data
      Map<String, double> dailyIncome = {};
      Map<String, double> dailyExpense = {};

      for (var row in incomeTotal) {
        String date = row['date'] as String;
        dailyIncome[date] = (row['daily_total'] as num).toDouble();
      }

      for (var row in expenseTotal) {
        String date = row['date'] as String;
        dailyExpense[date] = (row['daily_total'] as num).toDouble();
      }

      // Load category data for selected type
      String whereClause = "type = ? AND date BETWEEN ? AND ?";
      List<dynamic> whereArgs = [
        selectedType,
        start.toIso8601String().substring(0, 10),
        end.toIso8601String().substring(0, 10),
      ];

      final transactions = await db.query(
        'transactions',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'amount DESC', // Order by amount to show highest first
      );

      Map<String, double> categoryData = {};
      double typeTotal = 0;

      for (var transaction in transactions) {
        String category = transaction['category'] as String;
        double amount = (transaction['amount'] as num).toDouble();
        categoryData[category] = (categoryData[category] ?? 0) + amount;
        typeTotal += amount;
      }

      // Calculate percentages only if there is data
      Map<String, double> categoryPercentages = {};
      if (typeTotal > 0) {
        categoryData.forEach((key, value) {
          categoryPercentages[key] = (value / typeTotal) * 100;
        });
      }

      return {
        "categoryData": categoryData,
        "categoryPercentages": categoryPercentages,
        "total": typeTotal,
        "incomeTotal": (incomeTotal.isEmpty
            ? 0.0
            : incomeTotal.fold(0.0,
                (sum, row) => sum + (row['daily_total'] as num).toDouble())),
        "expenseTotal": (expenseTotal.isEmpty
            ? 0.0
            : expenseTotal.fold(0.0,
                (sum, row) => sum + (row['daily_total'] as num).toDouble())),
        "dailyIncome": dailyIncome,
        "dailyExpense": dailyExpense,
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
          'Financial Report',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF64B5F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        color: Theme.of(context).colorScheme.background,
        child: Column(
          children: [
            // Date range and chart toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.date_range,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${DateFormat('MMM d, y').format(selectedStartDate ?? DateTime.now())} - ${DateFormat('MMM d, y').format(selectedEndDate ?? DateTime.now())}',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.calendar_today),
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: () async {
                      try {
                        final now = DateTime.now();
                        final DateTimeRange? dateRange = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(now.year, now.month + 1, 0),
                          initialDateRange: DateTimeRange(
                            start: selectedStartDate ?? DateTime(now.year, now.month, 1),
                            end: selectedEndDate ?? now,
                          ),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (dateRange != null) {
                          print('Date range selected: ${dateRange.start} to ${dateRange.end}');
                          setState(() {
                            selectedStartDate = dateRange.start;
                            selectedEndDate = dateRange.end;
                            _reportsFuture = _loadData();
                          });
                        }
                      } catch (e) {
                        print('Error selecting date range: $e');
                      }
                    },
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Main content
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _reportsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.hasError) {
                    return Center(
                      child: Text(
                        'No data available',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                        ),
                      ),
                    );
                  }

                  final data = snapshot.data!;
                  final categoryData =
                      data['categoryData'] as Map<String, double>;
                  final categoryPercentages =
                      data['categoryPercentages'] as Map<String, double>;
                  final incomeTotal = data['incomeTotal'] as double;
                  final expenseTotal = data['expenseTotal'] as double;
                  final dailyIncome =
                      data['dailyIncome'] as Map<String, double>;
                  final dailyExpense =
                      data['dailyExpense'] as Map<String, double>;
                  final total =
                      selectedType == 'income' ? incomeTotal : expenseTotal;

                  return Column(
                    children: [
                      // Chart type selector
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.pie_chart,
                                size: 24,
                                color: _chartType == ChartType.pie
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                              ),
                              onPressed: () {
                                setState(() {
                                  _chartType = ChartType.pie;
                                });
                              },
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: Icon(
                                Icons.bar_chart,
                                size: 24,
                                color: _chartType == ChartType.bar
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                              ),
                              onPressed: () {
                                setState(() {
                                  _chartType = ChartType.bar;
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                      // Chart Section
                      Container(
                        height: 280,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: _buildChartSection(
                            context,
                            chartType: _chartType,
                            categoryData: categoryData,
                            categoryPercentages: categoryPercentages,
                            dailyIncome: dailyIncome,
                            dailyExpense: dailyExpense,
                            total: total,
                          ),
                        ),
                      ),

                      // Type Selector
                      Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  backgroundColor: selectedType == 'income'
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                      : Colors.transparent,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () {
                                  setState(() {
                                    selectedType = 'income';
                                    _reportsFuture = _loadData();
                                  });
                                },
                                child: Text(
                                  'Income',
                                  style: TextStyle(
                                    color: selectedType == 'income'
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  backgroundColor: selectedType == 'expense'
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                      : Colors.transparent,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () {
                                  setState(() {
                                    selectedType = 'expense';
                                    _reportsFuture = _loadData();
                                  });
                                },
                                child: Text(
                                  'Expenses',
                                  style: TextStyle(
                                    color: selectedType == 'expense'
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Category List Header
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Text(
                              'Categories',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Total: $_currencySymbol${total.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Category list
                      Expanded(
                        child: categoryData.isEmpty
                            ? Center(
                                child: Text(
                                  'No ${selectedType} data for selected period',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.6),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(bottom: 16),
                                itemCount: categoryData.length,
                                itemBuilder: (context, index) {
                                  final entry =
                                      categoryData.entries.elementAt(index);
                                  final percentage =
                                      categoryPercentages[entry.key] ?? 0;
                                  return _buildCategoryItem(
                                    context,
                                    category: entry.key,
                                    amount: entry.value,
                                    percentage: percentage,
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$_currencySymbol${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(
    BuildContext context, {
    required ChartType chartType,
    required Map<String, double> categoryData,
    required Map<String, double> categoryPercentages,
    required Map<String, double> dailyIncome,
    required Map<String, double> dailyExpense,
    required double total,
  }) {
    if (chartType == ChartType.pie) {
      if (categoryData.isEmpty) {
        return Center(
          child: Text(
            'No ${selectedType} data for selected period',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        );
      }

      return PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 60,
          sections: categoryData.entries.map((entry) {
            final percentage = categoryPercentages[entry.key] ?? 0;
            return PieChartSectionData(
              color: _getCategoryColor(entry.key),
              value: entry.value,
              title: percentage >= 5 ? '${percentage.toStringAsFixed(1)}%' : '',
              radius: 24,
              titleStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 2,
                  ),
                ],
              ),
              badgeWidget: percentage >= 10
                  ? _buildCategoryBadge(entry.key, percentage)
                  : null,
              badgePositionPercentageOffset: 1.1,
            );
          }).toList(),
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, pieTouchResponse) {},
            enabled: true,
          ),
        ),
      );
    } else {
      // Bar chart
      // Check if there's data to display
      if (dailyIncome.isEmpty && dailyExpense.isEmpty) {
        return Center(
          child: Text(
            'No transaction data for selected period',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        );
      }
      
      // Calculate max Y value safely
      double maxY = 100.0; // Default value if no data
      if (dailyIncome.isNotEmpty || dailyExpense.isNotEmpty) {
        final allValues = [...dailyIncome.values, ...dailyExpense.values];
        if (allValues.isNotEmpty) {
          maxY = allValues.reduce((max, value) => value > max ? value : max) * 1.2;
        }
      }
      
      return BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceBetween,
          maxY: maxY,
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final allDates = {...dailyIncome.keys, ...dailyExpense.keys}
                      .toList()
                    ..sort();
                  if (value.toInt() >= 0 && value.toInt() < allDates.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        DateFormat('MMM d')
                            .format(DateTime.parse(allDates[value.toInt()])),
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                        ),
                      ),
                    );
                  }
                  return const SizedBox();
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '$_currencySymbol${value.toInt()}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                  );
                },
                reservedSize: 40,
              ),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Theme.of(context).dividerColor,
                strokeWidth: 0.5,
              );
            },
          ),
          borderData: FlBorderData(show: false),
          barGroups: _createBarGroups(dailyIncome, dailyExpense),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (barGroup) =>
                  Theme.of(context).colorScheme.surface,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final date = {...dailyIncome.keys, ...dailyExpense.keys}
                    .toList()[group.x.toInt()];
                return BarTooltipItem(
                  '${DateFormat('MMM d, y').format(DateTime.parse(date))}\n',
                  TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    TextSpan(
                      text:
                          'Income: $_currencySymbol${dailyIncome[date]?.toStringAsFixed(0) ?? '0'}',
                      style: TextStyle(
                        color: Colors.green,
                      ),
                    ),
                    const TextSpan(text: '\n'),
                    TextSpan(
                      text:
                          'Expense: $_currencySymbol${dailyExpense[date]?.toStringAsFixed(0) ?? '0'}',
                      style: TextStyle(
                        color: Colors.red,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    }
  }

  Widget _buildCategoryItem(
    BuildContext context, {
    required String category,
    required double amount,
    required double percentage,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getCategoryColor(category).withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              _getCategoryIcon(category),
              size: 20,
              color: _getCategoryColor(category),
            ),
          ),
        ),
        title: Text(
          category,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
          color: _getCategoryColor(category),
          minHeight: 4,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$_currencySymbol${amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(String category, double percentage) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
        category,
        style: TextStyle(
          color: Colors.black87,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    // Predefined colors list for dynamic assignment
    final List<Color> colorPalette = [
      const Color(0xFF2196F3), // Blue
      const Color(0xFFFF9800), // Orange
      const Color(0xFFE91E63), // Pink
      const Color(0xFF4CAF50), // Green
      const Color(0xFF9C27B0), // Purple
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFFF44336), // Red
      const Color(0xFF795548), // Brown
      const Color(0xFF009688), // Teal
      const Color(0xFF673AB7), // Deep Purple
      const Color(0xFFFF5722), // Deep Orange
      const Color(0xFF3F51B5), // Indigo
    ];

    // Generate a consistent index for the category based on its name
    final int colorIndex = category.hashCode.abs() % colorPalette.length;
    return colorPalette[colorIndex];
  }

  IconData _getCategoryIcon(String category) {
    // Common words to icon mappings
    final Map<String, IconData> commonIconMappings = {
      'food': Icons.restaurant,
      'meal': Icons.restaurant,
      'restaurant': Icons.restaurant,
      'grocery': Icons.shopping_basket,
      'transport': Icons.directions_car,
      'taxi': Icons.local_taxi,
      'car': Icons.directions_car,
      'bus': Icons.directions_bus,
      'entertainment': Icons.movie,
      'movie': Icons.movie,
      'game': Icons.games,
      'medicine': Icons.local_hospital,
      'health': Icons.health_and_safety,
      'hospital': Icons.local_hospital,
      'shopping': Icons.shopping_cart,
      'internet': Icons.wifi,
      'wifi': Icons.wifi,
      'web': Icons.language,
      'bill': Icons.receipt,
      'bills': Icons.receipt,
      'invoice': Icons.receipt_long,
      'education': Icons.school,
      'study': Icons.school,
      'course': Icons.cast_for_education,
      'house': Icons.home,
      'home': Icons.home,
      'rent': Icons.house,
      'insurance': Icons.security,
      'utility': Icons.power,
      'utilities': Icons.power,
      'electricity': Icons.electric_bolt,
      'water': Icons.water_drop,
      'salary': Icons.account_balance_wallet,
      'wage': Icons.account_balance_wallet,
      'income': Icons.attach_money,
      'investment': Icons.trending_up,
      'stock': Icons.show_chart,
      'crypto': Icons.currency_bitcoin,
      'freelance': Icons.work,
      'business': Icons.business,
      'dividend': Icons.pie_chart,
      'interest': Icons.percent,
      'bonus': Icons.star,
      'gift': Icons.card_giftcard,
      'present': Icons.card_giftcard,
      'phone': Icons.phone_android,
      'mobile': Icons.phone_android,
      'clothing': Icons.checkroom,
      'clothes': Icons.checkroom,
      'travel': Icons.flight,
      'holiday': Icons.beach_access,
      'vacation': Icons.beach_access,
      'sport': Icons.sports,
      'fitness': Icons.fitness_center,
      'gym': Icons.fitness_center,
      'pet': Icons.pets,
      'beauty': Icons.face,
      'cosmetics': Icons.face,
      'book': Icons.book,
      'subscription': Icons.subscriptions,
      'donation': Icons.volunteer_activism,
      'charity': Icons.volunteer_activism,
      'tax': Icons.account_balance,
      'other': Icons.more_horiz,
      'others': Icons.more_horiz,
      'miscellaneous': Icons.more_horiz,
    };

    // Convert category to lowercase for matching
    final String lowercaseCategory = category.toLowerCase();

    // Try to find a matching icon based on category words
    for (var entry in commonIconMappings.entries) {
      if (lowercaseCategory.contains(entry.key)) {
        return entry.value;
      }
    }

    // If no specific match found, use a generic icon based on type
    if (selectedType == 'income') {
      return Icons.attach_money;
    }

    // Default icon for expenses
    return Icons.shopping_bag;
  }

  List<BarChartGroupData> _createBarGroups(
      Map<String, double> dailyIncome, Map<String, double> dailyExpense) {
    final allDates = {...dailyIncome.keys, ...dailyExpense.keys}.toList()
      ..sort();

    return List.generate(allDates.length, (index) {
      final date = allDates[index];
      final income = dailyIncome[date] ?? 0;
      final expense = dailyExpense[date] ?? 0;

      return BarChartGroupData(
        x: index,
        groupVertically: true,
        barRods: [
          BarChartRodData(
            toY: income,
            color: Colors.green.withOpacity(0.7),
            width: 8,
            borderRadius: BorderRadius.zero,
          ),
          BarChartRodData(
            toY: expense,
            color: Colors.red.withOpacity(0.7),
            width: 8,
            borderRadius: BorderRadius.zero,
          ),
        ],
      );
    });
  }
}

enum ChartType {
  pie,
  bar,
}
