import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/expense.dart';
import '../services/database_service.dart';
import 'dart:developer' as developer;

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<Expense> _expenses = [];
  DateTimeRange? _selectedDateRange;
  bool _isExporting = false;
  String _logMessages = '';

  void _log(String message) {
    developer.log(message, name: 'PDFExport');
    _logMessages += '$message\n';
    // Removed print statement to fix linter warning
  }

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    final expenses = await DatabaseService().getExpenses();
    if (mounted) {
      setState(() {
        _expenses = expenses;
      });
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
      _loadExpenses();
    }
  }

  Map<String, double> _calculateSpendingByCategory(List<Expense> expenses) {
    final Map<String, double> spendingByCategory = {};
    for (final expense in expenses) {
      if (spendingByCategory.containsKey(expense.category)) {
        spendingByCategory[expense.category] =
            spendingByCategory[expense.category]! + expense.amount;
      } else {
        spendingByCategory[expense.category] = expense.amount;
      }
    }
    return spendingByCategory;
  }

  Future<void> _showDebugLog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Debug Log'),
        content: SingleChildScrollView(
          child: Text(_logMessages),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _logMessages));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Log copied to clipboard'),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.of(context).pop();
            },
            child: Text('Copy to Clipboard'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportAsPDF() async {
    setState(() {
      _isExporting = true;
      _logMessages = ''; // Clear previous logs
    });

    try {
      _log('Starting PDF export process');

      // Check if expenses data exists
      if (_expenses.isEmpty) {
        _log('WARNING: No expenses data available');
      } else {
        _log('Expenses count: ${_expenses.length}');
        _log(
            'Categories count: ${_expenses.map((e) => e.category).toSet().length}');
      }

      // Try the simplest possible PDF generation first
      _log('Creating minimal test PDF document');
      final testPdf = pw.Document();

      testPdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Text('Test PDF'),
            );
          },
        ),
      );

      try {
        _log('Saving minimal test PDF...');
        final testBytes = await testPdf.save();
        _log('Test PDF generated successfully: ${testBytes.length} bytes');

        // Now we know PDF generation works at a basic level, let's try with actual data
        final spendingByCategory = _calculateSpendingByCategory(_expenses);
        final totalSpending =
            spendingByCategory.values.fold(0.0, (sum, amount) => sum + amount);

        _log('Creating full PDF document');
        final fullPdf = pw.Document();

        fullPdf.addPage(
          pw.Page(
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Spending by Category',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  ...spendingByCategory.entries.map((entry) {
                    final percentage = (entry.value / totalSpending) * 100;
                    return pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 5),
                      child: pw.Row(
                        children: [
                          pw.Container(
                            width: 10,
                            height: 10,
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromInt(
                                Colors
                                    .primaries[spendingByCategory.keys
                                            .toList()
                                            .indexOf(entry.key) %
                                        Colors.primaries.length]
                                    .value,
                              ),
                              shape: pw.BoxShape.circle,
                            ),
                          ),
                          pw.SizedBox(width: 10),
                          pw.Expanded(child: pw.Text(entry.key)),
                          pw.Text('${percentage.toStringAsFixed(1)}%'),
                          pw.SizedBox(width: 10),
                          pw.Text('\$${entry.value.toStringAsFixed(2)}'),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              );
            },
          ),
        );

        _log('Saving full PDF...');
        final bytes = await fullPdf.save();
        _log('Full PDF generated successfully: ${bytes.length} bytes');

        if (Platform.isIOS) {
          _log('iOS detected, using iOS-specific file handling');
          // Get application documents directory for iOS
          final directory = await getApplicationDocumentsDirectory();
          final filePath = '${directory.path}/spending_report.pdf';
          _log('iOS file path: $filePath');

          final file = File(filePath);
          await file.writeAsBytes(bytes);
          _log('File written successfully to iOS documents directory');

          // Share the file with the user
          _log('Showing share dialog for iOS');
          await Share.shareFiles([filePath], text: 'Your expense report');
          _log('Share dialog shown');
        } else {
          // Other platforms (Android, desktop) use FilePicker
          _log('Non-iOS platform detected, using FilePicker');
          final String? outputPath = await FilePicker.platform.saveFile(
            dialogTitle: 'Save PDF Report',
            fileName: 'spending_report.pdf',
            allowedExtensions: ['pdf'],
          );

          if (outputPath == null) {
            _log('User cancelled file selection');
            return;
          }

          _log('Selected file path: $outputPath');

          // Write the file
          _log('Writing PDF to file...');
          final file = File(outputPath);

          try {
            _log('Using writeAsBytes method...');
            await file.writeAsBytes(bytes);
            _log('File written successfully with writeAsBytes');
          } catch (e) {
            _log('writeAsBytes failed: $e');

            // Try alternative approach
            _log('Trying alternative approach with open/write/close...');
            final sink = file.openWrite();
            sink.add(bytes);
            await sink.flush();
            await sink.close();
            _log('File written successfully with open/write/close');
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF export successful'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        _log('Failed to save even minimal PDF: $e');
        throw Exception('Basic PDF generation failed: $e');
      }
    } catch (e, stackTrace) {
      _log('ERROR during PDF export: $e');
      _log('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export PDF: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Show Log',
              onPressed: _showDebugLog,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _exportAsCSV() async {
    setState(() {
      _isExporting = true;
      _logMessages = ''; // Clear previous logs
    });

    try {
      _log('Starting CSV export process');
      final spendingByCategory = _calculateSpendingByCategory(_expenses);
      _log(
          'Calculated spending by category: ${spendingByCategory.length} categories');

      final totalSpending =
          spendingByCategory.values.fold(0.0, (sum, amount) => sum + amount);
      _log('Total spending: $totalSpending');

      final List<List<dynamic>> csvData = [];
      csvData.add(['Category', 'Amount', 'Percentage']);

      spendingByCategory.forEach((category, amount) {
        final percentage = (amount / totalSpending) * 100;
        csvData.add([category, amount, percentage]);
      });
      _log('CSV data prepared: ${csvData.length} rows');

      _log('Converting data to CSV string');
      final csv = const ListToCsvConverter().convert(csvData);
      _log('CSV string generated: ${csv.length} characters');

      if (Platform.isIOS) {
        _log('iOS detected, using iOS-specific file handling');
        // Get application documents directory for iOS
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/spending_report.csv';
        _log('iOS file path: $filePath');

        final file = File(filePath);
        await file.writeAsString(csv);
        _log('File written successfully to iOS documents directory');

        // Share the file with the user
        _log('Showing share dialog for iOS');
        await Share.shareFiles([filePath], text: 'Your expense report');
        _log('Share dialog shown');
      } else {
        // Other platforms (Android, desktop) use FilePicker
        _log('Non-iOS platform detected, using FilePicker');
        final String? outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save CSV Report',
          fileName: 'spending_report.csv',
          allowedExtensions: ['csv'],
        );

        if (outputPath == null) {
          _log('User cancelled file selection');
          return;
        }

        _log('Selected file path: $outputPath');

        // Write the file
        _log('Writing CSV to file...');
        final file = File(outputPath);

        try {
          _log('Using writeAsString method...');
          await file.writeAsString(csv);
          _log('File written successfully with writeAsString');
        } catch (e) {
          _log('writeAsString failed: $e');

          // Try alternative approach
          _log('Trying alternative approach with open/write/close...');
          final sink = file.openWrite();
          sink.write(csv);
          await sink.flush();
          await sink.close();
          _log('File written successfully with open/write/close');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV export successful'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      _log('ERROR during CSV export: $e');
      _log('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export CSV: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Show Log',
              onPressed: _showDebugLog,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final spendingByCategory = _calculateSpendingByCategory(_expenses);
    final totalSpending =
        spendingByCategory.values.fold(0.0, (sum, amount) => sum + amount);

    return Scaffold(
      appBar: AppBar(
        title: Text('Financial Reports'),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: () => _selectDateRange(context),
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: Text('Export as PDF'),
                onTap: () {
                  Future.delayed(
                    const Duration(seconds: 0),
                    _exportAsPDF,
                  );
                },
              ),
              PopupMenuItem(
                child: Text('Export as CSV'),
                onTap: () {
                  Future.delayed(
                    const Duration(seconds: 0),
                    _exportAsCSV,
                  );
                },
              ),
              PopupMenuItem(
                child: Text('Show Debug Log'),
                onTap: () {
                  Future.delayed(
                    const Duration(seconds: 0),
                    _showDebugLog,
                  );
                },
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Spending by Category',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                Expanded(
                  child: spendingByCategory.isEmpty
                      ? Center(child: Text('No expenses data available'))
                      : PieChart(
                          PieChartData(
                            sections: spendingByCategory.entries.map((entry) {
                              final percentage =
                                  (entry.value / totalSpending) * 100;
                              return PieChartSectionData(
                                value: entry.value,
                                title: '${percentage.toStringAsFixed(1)}%',
                                color: Colors.primaries[spendingByCategory.keys
                                        .toList()
                                        .indexOf(entry.key) %
                                    Colors.primaries.length],
                                radius: 100,
                                titleStyle: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              );
                            }).toList(),
                            centerSpaceRadius: 40,
                            sectionsSpace: 2,
                          ),
                        ),
                ),
                SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    children: spendingByCategory.entries.map((entry) {
                      final percentage = (entry.value / totalSpending) * 100;
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.primaries[spendingByCategory.keys
                                      .toList()
                                      .indexOf(entry.key) %
                                  Colors.primaries.length],
                              shape: BoxShape.circle,
                            ),
                          ),
                          title: Text(entry.key),
                          trailing: Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            '\$${entry.value.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          if (_isExporting)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Exporting...',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
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
}
