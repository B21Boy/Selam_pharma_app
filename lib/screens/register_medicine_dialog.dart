import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/pharmacy_provider.dart';
import '../models/medicine.dart';
// Cloudinary upload is handled by SyncService; keep dialog offline-first.

class RegisterMedicineDialog extends StatefulWidget {
  const RegisterMedicineDialog({super.key});

  @override
  RegisterMedicineDialogState createState() => RegisterMedicineDialogState();
}

class RegisterMedicineDialogState extends State<RegisterMedicineDialog>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _totalQtyController = TextEditingController();
  final _buyPriceController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _barcodeController = TextEditingController();

  Uint8List? _imageBytes;
  String _selectedCategory = 'Others';
  bool _isExpanded = false;
  bool _showSuccess = false;
  bool _isLoading = false;
  late AnimationController _successAnimationController;
  late Animation<double> _successAnimation;
  late AnimationController _loadingAnimationController;
  late Animation<double> _loadingAnimation;

  final List<String> _categories = ['Antibiotics', 'Cosmetics', 'Others'];

  // Template and recent items data
  final List<Map<String, dynamic>> _recentMedicines = [];
  final List<Map<String, dynamic>> _savedTemplates = [];

  // Validation states
  bool _isNameValid = true;
  bool _isQtyValid = true;
  bool _isBuyPriceValid = true;
  bool _isSellPriceValid = true;

  // Pharmacy-themed colors
  static const Color _primaryBlue = Color(0xFF1976D2);
  static const Color _accentGreen = Color(0xFF4CAF50);
  static const Color _successColor = Color(0xFF4CAF50);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load saved templates and recent items after context is available
    if (_recentMedicines.isEmpty) {
      _loadSavedData();
    }
  }

  @override
  void initState() {
    super.initState();
    _successAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _successAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _loadingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
    _loadingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _loadingAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Add listeners for real-time validation
    _nameController.addListener(_validateName);
    _totalQtyController.addListener(_validateQuantity);
    _buyPriceController.addListener(_validateBuyPrice);
    _sellPriceController.addListener(_validateSellPrice);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _totalQtyController.dispose();
    _buyPriceController.dispose();
    _sellPriceController.dispose();
    _successAnimationController.dispose();
    _loadingAnimationController.dispose();
    super.dispose();
  }

  // Real-time validation methods
  void _validateName() {
    setState(() {
      _isNameValid = _nameController.text.trim().isNotEmpty;
    });
  }

  void _validateQuantity() {
    setState(() {
      final qty = int.tryParse(_totalQtyController.text);
      _isQtyValid = qty != null && qty > 0;
    });
  }

  void _validateBuyPrice() {
    setState(() {
      final price = double.tryParse(
        _buyPriceController.text.replaceAll('₹', '').replaceAll(',', ''),
      );
      _isBuyPriceValid = price != null && price > 0;
    });
  }

  void _validateSellPrice() {
    setState(() {
      final price = double.tryParse(
        _sellPriceController.text.replaceAll('₹', '').replaceAll(',', ''),
      );
      _isSellPriceValid = price != null && price > 0;
    });
  }

  // Quantity increment/decrement
  void _incrementQuantity() {
    final currentQty = int.tryParse(_totalQtyController.text) ?? 0;
    _totalQtyController.text = (currentQty + 1).toString();
  }

  void _decrementQuantity() {
    final currentQty = int.tryParse(_totalQtyController.text) ?? 0;
    if (currentQty > 1) {
      _totalQtyController.text = (currentQty - 1).toString();
    }
  }

  // Helper method to safely parse price strings
  int _parsePrice(String priceText) {
    final cleaned = priceText.replaceAll('₹', '').replaceAll(',', '');
    final parts = cleaned.split('.');
    return int.parse(parts[0]);
  }

  // Price formatting
  String _formatPrice(String value) {
    if (value.isEmpty) return '';
    final numericValue = value.replaceAll('₹', '').replaceAll(',', '');
    final doubleValue = double.tryParse(numericValue);
    if (doubleValue == null) return value;

    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    return formatter.format(doubleValue);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      // Show error message for camera/gallery issues
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              source == ImageSource.camera
                  ? 'Camera not available on this device'
                  : 'Failed to access gallery',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Load saved templates and recent items
  void _loadSavedData() {
    // In a real app, this would load from shared preferences or database
    // For demo purposes, we'll initialize with some sample data
    _savedTemplates.addAll([
      {
        'name': 'Paracetamol 500mg',
        'category': 'Antibiotics',
        'buyPrice': 2.50,
        'sellPrice': 5.00,
        'quantity': 100,
      },
      {
        'name': 'Vitamin C 1000mg',
        'category': 'Cosmetics',
        'buyPrice': 8.00,
        'sellPrice': 15.00,
        'quantity': 50,
      },
    ]);

    // Load recent medicines from provider
    final provider = context.read<PharmacyProvider>();
    _recentMedicines.clear();
    // Get last 5 medicines (in a real app, this would be stored separately)
    final allMedicines = provider.medicines;
    if (allMedicines.length > 5) {
      _recentMedicines.addAll(
        allMedicines
            .sublist(allMedicines.length - 5)
            .map(
              (medicine) => {
                'name': medicine.name,
                'category': medicine.category ?? 'Others',
                'buyPrice': medicine.buyPrice.toDouble(),
                'sellPrice': medicine.sellPrice.toDouble(),
                'quantity': medicine.totalQty,
              },
            ),
      );
    } else {
      _recentMedicines.addAll(
        allMedicines.map(
          (medicine) => {
            'name': medicine.name,
            'category': medicine.category ?? 'Others',
            'buyPrice': medicine.buyPrice.toDouble(),
            'sellPrice': medicine.sellPrice.toDouble(),
            'quantity': medicine.totalQty,
          },
        ),
      );
    }
  }

  // Apply template data to form
  void _applyTemplate(Map<String, dynamic> template) {
    setState(() {
      _nameController.text = template['name'];
      _selectedCategory = template['category'];
      _buyPriceController.text = _formatPrice(template['buyPrice'].toString());
      _sellPriceController.text = _formatPrice(
        template['sellPrice'].toString(),
      );
      _totalQtyController.text = template['quantity'].toString();
    });
  }

  // Save current form as template
  void _saveAsTemplate() {
    if (_nameController.text.isNotEmpty) {
      final template = {
        'name': _nameController.text,
        'category': _selectedCategory,
        'buyPrice':
            double.tryParse(
              _buyPriceController.text.replaceAll('₹', '').replaceAll(',', ''),
            ) ??
            0.0,
        'sellPrice':
            double.tryParse(
              _sellPriceController.text.replaceAll('₹', '').replaceAll(',', ''),
            ) ??
            0.0,
        'quantity': int.tryParse(_totalQtyController.text) ?? 1,
      };

      setState(() {
        _savedTemplates.add(template);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Template saved successfully!'),
          backgroundColor: _successColor,
        ),
      );
    }
  }

  // Scan barcode and auto-fill medicine details
  Future<void> _scanBarcode() async {
    // Get provider before async operations
    final provider = context.read<PharmacyProvider>();
    final messenger = ScaffoldMessenger.of(context);

    // Request camera permission
    var status = await Permission.camera.request();
    if (!mounted) return;
    if (!status.isGranted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Camera permission is required for barcode scanning'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Show scanner dialog
      final result = await showDialog<String>(
        context: context,
        builder: (context) => Dialog(
          child: SizedBox(
            height: 400,
            child: MobileScanner(
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  final barcode = barcodes.first.rawValue;
                  if (barcode != null) {
                    Navigator.of(context).pop(barcode);
                  }
                }
              },
            ),
          ),
        ),
      );

      if (result != null) {
        // Lookup medicine by barcode
        final medicine = provider.findMedicineByBarcode(result);

        if (medicine != null) {
          // Auto-fill fields
          setState(() {
            _nameController.text = medicine.name;
            _totalQtyController.text = medicine.totalQty.toString();
            _buyPriceController.text = medicine.buyPrice.toString();
            _sellPriceController.text = medicine.sellPrice.toString();
            _selectedCategory = medicine.category ?? 'Others';
            _imageBytes = medicine.imageBytes;
            _barcodeController.text = medicine.barcode ?? '';
          });

          messenger.showSnackBar(
            SnackBar(
              content: Text('Medicine "${medicine.name}" loaded from barcode'),
              backgroundColor: _accentGreen,
            ),
          );
        } else {
          // Set barcode for new medicine
          setState(() {
            _barcodeController.text = result;
          });
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Barcode scanned. Please enter medicine details.'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Scanning failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _registerMedicine() async {
    if (_formKey.currentState!.validate()) {
      final provider = context.read<PharmacyProvider>();

      // Check if medicine already exists
      final medicineName = _nameController.text.trim().toLowerCase();
      final existingMedicine = provider.medicines.any(
        (medicine) => medicine.name.toLowerCase() == medicineName,
      );

      if (existingMedicine) {
        // Show alert dialog for existing medicine
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Medicine Already Exists'),
              content: const Text(
                'This medicine is already registered in the system.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      // Simulate processing time
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      final medicine = Medicine(
        id: Uuid().v4(),
        name: _nameController.text.trim(),
        totalQty: int.parse(_totalQtyController.text),
        buyPrice: _parsePrice(_buyPriceController.text),
        sellPrice: _parsePrice(_sellPriceController.text),
        imageBytes: _imageBytes,
        category: _selectedCategory,
        barcode: _barcodeController.text.isNotEmpty
            ? _barcodeController.text
            : null,
      );

      // Always save image bytes locally first so the app works offline.
      // The SyncService will upload images and sync to Firestore when
      // network/auth conditions allow.
      if (_imageBytes != null) {
        medicine.imageBytes = _imageBytes;
      }
      medicine.lastModifiedMillis = DateTime.now().millisecondsSinceEpoch;

      await provider.addMedicine(medicine);
      if (!mounted) return;

      // Add to recent items
      final recentItem = {
        'name': medicine.name,
        'category': medicine.category,
        'buyPrice': medicine.buyPrice.toDouble(),
        'sellPrice': medicine.sellPrice.toDouble(),
        'quantity': medicine.totalQty,
      };
      setState(() {
        _recentMedicines.add(recentItem);
        if (_recentMedicines.length > 5) {
          _recentMedicines.removeAt(0);
        }
        _isLoading = false;
        _showSuccess = true;
      });

      _successAnimationController.forward();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medicine registered successfully!'),
          backgroundColor: _successColor,
        ),
      );

      // Close dialog after animation
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          Navigator.of(context).pop(_selectedCategory);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isLandscape ? screenWidth * 0.6 : screenWidth * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          style: IconButton.styleFrom(
                            foregroundColor: _primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Register Medicine',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _primaryBlue,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Template Menu
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'save') {
                                  _saveAsTemplate();
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'save',
                                  child: Row(
                                    children: [
                                      Icon(Icons.save, color: _primaryBlue),
                                      SizedBox(width: 8),
                                      Text('Save as Template'),
                                    ],
                                  ),
                                ),
                                const PopupMenuDivider(),
                                ..._savedTemplates.map(
                                  (template) => PopupMenuItem(
                                    value:
                                        'template_${_savedTemplates.indexOf(template)}',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.bookmark,
                                          color: _accentGreen,
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            template['name'],
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: () => _applyTemplate(template),
                                  ),
                                ),
                              ],
                              icon: const Icon(
                                Icons.more_vert,
                                color: _primaryBlue,
                              ),
                              tooltip: 'Templates & Options',
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: () =>
                                  setState(() => _isExpanded = !_isExpanded),
                              icon: Icon(
                                _isExpanded
                                    ? Icons.fullscreen_exit
                                    : Icons.fullscreen,
                                color: _primaryBlue,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: _isExpanded
                                  ? 'Exit full screen'
                                  : 'Full screen mode',
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Templates Section
                    if (_savedTemplates.isNotEmpty) _buildTemplatesSection(),

                    const SizedBox(height: 8),

                    // Recent Items Section (only show if has recent items)
                    if (_recentMedicines.isNotEmpty) _buildRecentItemsSection(),

                    const SizedBox(height: 16),

                    // Basic Information Section
                    _buildSectionCard(
                      title: 'Basic Information',
                      icon: Icons.info_outline,
                      children: [
                        // Medicine Name - Prominent field
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Medicine Name *',
                            hintText: 'Enter medicine name',
                            helperText: 'Enter the complete medicine name',
                            prefixIcon: const Icon(Icons.medication),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _isNameValid ? Colors.grey : Colors.red,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _isNameValid ? Colors.grey : Colors.red,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).primaryColor,
                                width: 2,
                              ),
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Medicine name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Category
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCategory,
                          decoration: InputDecoration(
                            labelText: 'Category *',
                            hintText: 'Select medicine category',
                            helperText: 'Choose the appropriate category',
                            prefixIcon: const Icon(Icons.category),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                          dropdownColor: Colors.white,
                          items: _categories.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(
                                category,
                                style: const TextStyle(color: Colors.black87),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCategory = value!;
                            });
                          },
                          validator: (value) =>
                              value == null ? 'Please select a category' : null,
                        ),
                        const SizedBox(height: 16),

                        // Barcode (optional, shown when scanned or entered)
                        TextFormField(
                          controller: _barcodeController,
                          decoration: InputDecoration(
                            labelText: 'Barcode',
                            hintText: 'Scan or enter barcode',
                            helperText:
                                'Optional barcode for medicine identification',
                            prefixIcon: const Icon(Icons.qr_code),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.qr_code_scanner),
                              onPressed: _scanBarcode,
                              tooltip: 'Scan Barcode',
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Inventory Section
                    _buildSectionCard(
                      title: 'Inventory',
                      icon: Icons.inventory_2,
                      children: [
                        // Quantity with increment/decrement
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Quantity *',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: _decrementQuantity,
                                  icon: const Icon(Icons.remove),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).primaryColor.withValues(alpha: 0.1),
                                    minimumSize: const Size(48, 48),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: _totalQtyController,
                                    decoration: InputDecoration(
                                      hintText: 'Enter quantity',
                                      helperText: 'Number of units available',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: _isQtyValid
                                              ? Colors.grey
                                              : Colors.red,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: _isQtyValid
                                              ? Colors.grey
                                              : Colors.red,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Theme.of(context).primaryColor,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    style: const TextStyle(fontSize: 16),
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Quantity is required';
                                      }
                                      final qty = int.tryParse(value);
                                      if (qty == null || qty <= 0) {
                                        return 'Enter a valid quantity';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: _incrementQuantity,
                                  icon: const Icon(Icons.add),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).primaryColor.withValues(alpha: 0.1),
                                    minimumSize: const Size(48, 48),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Pricing Section
                    _buildSectionCard(
                      title: 'Pricing',
                      icon: Icons.attach_money,
                      children: [
                        // Buy Price
                        TextFormField(
                          controller: _buyPriceController,
                          decoration: InputDecoration(
                            labelText: 'Buy Price (per unit) *',
                            hintText: '₹0.00',
                            helperText: 'Cost price',
                            prefixIcon: const Icon(Icons.shopping_cart),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _isBuyPriceValid
                                    ? Colors.grey
                                    : Colors.red,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _isBuyPriceValid
                                    ? Colors.grey
                                    : Colors.red,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).primaryColor,
                                width: 2,
                              ),
                            ),
                          ),
                          style: const TextStyle(fontSize: 16),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.₹,]'),
                            ),
                          ],
                          onChanged: (value) {
                            final formatted = _formatPrice(value);
                            if (formatted != value) {
                              _buyPriceController.value = TextEditingValue(
                                text: formatted,
                                selection: TextSelection.collapsed(
                                  offset: formatted.length,
                                ),
                              );
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Buy price is required';
                            }
                            final price = double.tryParse(
                              value.replaceAll('₹', '').replaceAll(',', ''),
                            );
                            if (price == null || price <= 0) {
                              return 'Enter a valid price';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Sell Price
                        TextFormField(
                          controller: _sellPriceController,
                          decoration: InputDecoration(
                            labelText: 'Sell Price (per unit) *',
                            hintText: '₹0.00',
                            helperText: 'Selling price',
                            prefixIcon: const Icon(Icons.sell),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _isSellPriceValid
                                    ? Colors.grey
                                    : Colors.red,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _isSellPriceValid
                                    ? Colors.grey
                                    : Colors.red,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Theme.of(context).primaryColor,
                                width: 2,
                              ),
                            ),
                          ),
                          style: const TextStyle(fontSize: 16),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.₹,]'),
                            ),
                          ],
                          onChanged: (value) {
                            final formatted = _formatPrice(value);
                            if (formatted != value) {
                              _sellPriceController.value = TextEditingValue(
                                text: formatted,
                                selection: TextSelection.collapsed(
                                  offset: formatted.length,
                                ),
                              );
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Sell price is required';
                            }
                            final price = double.tryParse(
                              value.replaceAll('₹', '').replaceAll(',', ''),
                            );
                            if (price == null || price <= 0) {
                              return 'Enter a valid price';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Media Section
                    _buildSectionCard(
                      title: 'Media',
                      icon: Icons.photo_camera,
                      children: [
                        // Image picker buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _pickImage(ImageSource.camera),
                                icon: const Icon(Icons.camera_alt, size: 20),
                                label: const Text('Camera'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  minimumSize: const Size(0, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _pickImage(ImageSource.gallery),
                                icon: const Icon(Icons.photo_library, size: 20),
                                label: const Text('Gallery'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  minimumSize: const Size(0, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Image preview
                        if (_imageBytes != null) ...[
                          const SizedBox(height: 16),
                          Center(
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  _imageBytes!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Register Button
                    AnimatedBuilder(
                      animation: _loadingAnimation,
                      builder: (context, child) {
                        return ElevatedButton(
                          onPressed: _isLoading ? null : _registerMedicine,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: _isLoading ? 0 : 2,
                            backgroundColor: _isLoading
                                ? Colors.grey
                                : _primaryBlue,
                          ),
                          child: _isLoading
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              _primaryBlue,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Registering...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )
                              : const Text(
                                  'Register Medicine',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Success overlay
            if (_showSuccess)
              AnimatedBuilder(
                animation: _successAnimation,
                builder: (context, child) {
                  return Container(
                    color: Colors.black.withValues(alpha: 0.7),
                    child: Center(
                      child: Transform.scale(
                        scale: _successAnimation.value,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Medicine Registered!',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Successfully added to inventory',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: Colors.grey[600]),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplatesSection() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bookmark, color: _accentGreen, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Saved Templates',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _accentGreen,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _saveAsTemplate,
                  icon: Icon(Icons.add, color: _accentGreen),
                  tooltip: 'Save current as template',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _savedTemplates.length,
                itemBuilder: (context, index) {
                  final template = _savedTemplates[index];
                  return GestureDetector(
                    onTap: () => _applyTemplate(template),
                    child: Container(
                      width: 140,
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _accentGreen.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _accentGreen.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            template['name'] ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            template['category'] ?? 'Others',
                            style: TextStyle(fontSize: 10, color: _accentGreen),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₹${template['sellPrice'] ?? 0.0}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _primaryBlue,
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildRecentItemsSection() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: _primaryBlue, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Recent Items',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _recentMedicines.length,
                itemBuilder: (context, index) {
                  final item = _recentMedicines[index];
                  return GestureDetector(
                    onTap: () => _applyTemplate(item),
                    child: Container(
                      width: 140,
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _primaryBlue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _primaryBlue.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'] ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item['category'] ?? 'Others',
                            style: TextStyle(fontSize: 10, color: _primaryBlue),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₹${item['sellPrice'] ?? 0.0}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _accentGreen,
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: _primaryBlue, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}
