import 'package:flutter/material.dart';
import 'package:nur_budget/database/database_helper.dart';
import 'package:nur_budget/services/language_service.dart';
import '../utils/currency_utils.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _CategoryScreenState createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> with SingleTickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final LanguageService _languageService = LanguageService();
  
  late TabController _tabController;
  final TextEditingController _categoryNameController = TextEditingController();
  final TextEditingController _walletNameController = TextEditingController();
  
  List<Map<String, dynamic>> _incomeCategories = [];
  List<Map<String, dynamic>> _expenseCategories = [];
  List<Map<String, dynamic>> _wallets = [];
  
  Map<String, dynamic>? _editCategory;
  Map<String, dynamic>? _editWallet;
  String _currencySymbol = '\$';
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCategories();
    _loadWallets();
    _loadCurrency();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _categoryNameController.dispose();
    _walletNameController.dispose();
    super.dispose();
  }
  
  Future<void> _loadCurrency() async {
    final currency = await _dbHelper.getCurrency();
    if (mounted) {
      setState(() {
        _currencySymbol = getCurrencySymbol(currency);
      });
    }
  }
  
  Future<void> _loadCategories() async {
    _incomeCategories = await _dbHelper.getCategories('income');
    _expenseCategories = await _dbHelper.getCategories('expense');
    
    if (mounted) {
      setState(() {});
    }
  }
  
  Future<void> _loadWallets() async {
    _wallets = await _dbHelper.getAllWallets();
    
    if (mounted) {
      setState(() {});
    }
  }
  
  void _showAddCategoryDialog({Map<String, dynamic>? category}) {
    _editCategory = category;
    String type = _tabController.index == 0 ? 'income' : 'expense';
    
    if (category != null) {
      _categoryNameController.text = category['name'];
    } else {
      _categoryNameController.clear();
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(category != null 
            ? _languageService.translate('editCategory') 
            : _languageService.translate('addCategory')),
        content: TextField(
          controller: _categoryNameController,
          decoration: InputDecoration(
            labelText: _languageService.translate('categoryName'),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _categoryNameController.clear();
              _editCategory = null;
            },
            child: Text(_languageService.translate('cancel')),
          ),
          TextButton(
            onPressed: () async {
              if (_categoryNameController.text.isEmpty) return;
              
              if (_editCategory != null) {
                await _dbHelper.updateCategory(
                  {
                    'name': _categoryNameController.text,
                    'type': _editCategory!['type'],
                  },
                  _editCategory!['id'],
                );
              } else {
                await _dbHelper.insertCategory({
                  'name': _categoryNameController.text,
                  'type': type,
                });
              }
              
              if (mounted) {
                Navigator.pop(context);
                _categoryNameController.clear();
                _editCategory = null;
                _loadCategories();
              }
            },
            child: Text(_languageService.translate('save')),
          ),
        ],
      ),
    );
  }
  
  void _showAddWalletDialog({Map<String, dynamic>? wallet}) {
    _editWallet = wallet;
    bool isSaving = false;
    
    if (wallet != null) {
      _walletNameController.text = wallet['name'];
    } else {
      _walletNameController.clear();
    }
    
    showDialog(
      context: context,
      barrierDismissible: false, // prevent dismissing when saving
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(wallet != null 
                ? _languageService.translate('editWallet') 
                : _languageService.translate('addWallet')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _walletNameController,
                  decoration: InputDecoration(
                    labelText: _languageService.translate('walletName'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  autofocus: true,
                  enabled: !isSaving,
                ),
                if (isSaving) 
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving 
                  ? null 
                  : () {
                      Navigator.pop(context);
                      _walletNameController.clear();
                      _editWallet = null;
                    },
                child: Text(_languageService.translate('cancel')),
              ),
              TextButton(
                onPressed: isSaving 
                  ? null 
                  : () async {
                    if (_walletNameController.text.isEmpty) return;
                    
                    setState(() {
                      isSaving = true;
                    });
                    
                    try {
                      if (_editWallet != null) {
                        await _dbHelper.updateWallet(
                          {
                            'name': _walletNameController.text,
                            'balance': _editWallet!['balance'],
                          },
                          _editWallet!['id'],
                        );
                      } else {
                        await _dbHelper.insertWallet({
                          'name': _walletNameController.text,
                          'balance': 0.0,
                        });
                      }
                      
                      if (mounted) {
                        _walletNameController.clear();
                        _editWallet = null;
                        _loadWallets();
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      print("Error saving wallet: $e");
                      if (mounted) {
                        setState(() {
                          isSaving = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Error saving wallet: $e"))
                        );
                      }
                    }
                  },
                child: Text(_languageService.translate('save')),
              ),
            ],
          );
        }
      ),
    );
  }
  
  Future<void> _deleteCategory(Map<String, dynamic> category) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_languageService.translate('deleteCategory')),
        content: Text(_languageService.translate('deleteCategoryConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_languageService.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              _languageService.translate('delete'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    ) ?? false;
    
    if (confirm) {
      await _dbHelper.deleteCategory(category['id']);
      _loadCategories();
    }
  }
  
  Future<void> _deleteWallet(Map<String, dynamic> wallet) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_languageService.translate('deleteWallet')),
        content: Text(_languageService.translate('deleteWalletConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_languageService.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              _languageService.translate('delete'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    ) ?? false;
    
    if (confirm) {
      await _dbHelper.deleteWallet(wallet['id']);
      _loadWallets();
    }
  }
  
  Widget _buildCategoryList(List<Map<String, dynamic>> categories) {
    if (categories.isEmpty) {
      return Center(
        child: Text(_languageService.translate('noCategories')),
      );
    }
    
    return ListView.builder(
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            title: Text(category['name']),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showAddCategoryDialog(category: category),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteCategory(category),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildWalletList() {
    if (_wallets.isEmpty) {
      return Center(
        child: Text(_languageService.translate('noWallets')),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _wallets.isEmpty
            ? Expanded(
                child: Center(
                  child: Text(_languageService.translate('noWallets')),
                ),
              )
            : Expanded(
                child: ListView.builder(
                   itemCount: _wallets.length,
                   itemBuilder: (context, index) {
                     final wallet = _wallets[index];
                     final balance = wallet['balance'] as double;
                     
                     return Card(
                       elevation: 2,
                       margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                       child: ListTile(
                         title: Text(wallet['name']),
                         subtitle: Text(
                           '$_currencySymbol${balance.toStringAsFixed(2)}',
                           style: TextStyle(
                             fontWeight: FontWeight.bold,
                             color: balance >= 0 ? Colors.green : Colors.red,
                           ),
                         ),
                         trailing: Row(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             IconButton(
                               icon: const Icon(Icons.edit, color: Colors.blue),
                               onPressed: () => _showAddWalletDialog(wallet: wallet),
                             ),
                             IconButton(
                               icon: const Icon(Icons.delete, color: Colors.red),
                               onPressed: () => _deleteWallet(wallet),
                             ),
                           ],
                         ),
                       ),
                     );
                   },
                 ),
            ),
      ],
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _languageService.translate('categories'),
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
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: _languageService.translate('income')),
            Tab(text: _languageService.translate('expense')),
            Tab(text: _languageService.translate('wallets')),
          ],
          labelColor: Colors.white,
          onTap: (_) => setState(() {}),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCategoryList(_incomeCategories),
          _buildCategoryList(_expenseCategories),
          _buildWalletList(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 2) {
            _showAddWalletDialog();
          } else {
            _showAddCategoryDialog();
          }
        },
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
} 