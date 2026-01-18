import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/raffle_model.dart';
import '../../services/raffle_service.dart';
import '../../providers/admin_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive_layout.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class RaffleCreationScreen extends StatefulWidget {
  const RaffleCreationScreen({Key? key}) : super(key: key);

  @override
  State<RaffleCreationScreen> createState() => _RaffleCreationScreenState();
}

class _RaffleCreationScreenState extends State<RaffleCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _maxEntriesController = TextEditingController();
  final _prizeValueController = TextEditingController();
  final _prizeDescriptionController = TextEditingController();
  final _imageUrlController = TextEditingController(); // Image URL input

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _maxEntriesController.dispose();
    _prizeValueController.dispose();
    _prizeDescriptionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isTablet = ResponsiveLayout.isTablet(context);

    // Strict admin check - refresh status first
    return FutureBuilder<bool>(
      future: _verifyAdminStatus(adminProvider),
      builder: (context, snapshot) {
        // Show loading while checking
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppTheme.black,
            appBar: AppBar(
              backgroundColor: AppTheme.black,
              title: Text(
                'Verifying Access...',
                style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
              ),
              elevation: 0,
            ),
            body: const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGold),
            ),
          );
        }

        // Check if user is admin
        final isAdmin = snapshot.data ?? false;
        if (!isAdmin) {
          return Scaffold(
            backgroundColor: AppTheme.black,
            appBar: AppBar(
              backgroundColor: AppTheme.black,
              title: Text(
                'Access Denied',
                style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
              ),
              elevation: 0,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    color: AppTheme.red,
                    size: 64,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Admin Access Required',
                    style: AppTheme.headingLarge.copyWith(color: AppTheme.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Only administrators can create raffles.\n\nYour current role does not have permission to access this feature.',
                    style: AppTheme.bodyLarge.copyWith(color: AppTheme.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  CustomButton(
                    text: 'Go Back',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          );
        }

        // User is admin - show creation form
        return Scaffold(
          backgroundColor: AppTheme.black,
          appBar: isDesktop ? null : _buildMobileAppBar(),
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveLayout.getValueForScreenType<double>(
                  context: context,
                  mobile: 24.0,
                  tablet: 48.0,
                  desktop: 64.0,
                  largeDesktop: 80.0,
                ),
                vertical: 24.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Desktop header
                  if (isDesktop) _buildDesktopHeader(),

                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Basic Information
                        _buildSectionHeader('Raffle Information'),
                        const SizedBox(height: 16),
                        _buildBasicInfoSection(),

                        const SizedBox(height: 32),

                        // Prize Details
                        _buildSectionHeader('Prize Details (Gift Voucher)'),
                        const SizedBox(height: 16),
                        _buildPrizeDetailsSection(),

                        const SizedBox(height: 32),

                        // Dates and Settings
                        _buildSectionHeader('Raffle Duration'),
                        const SizedBox(height: 16),
                        _buildDatesAndSettingsSection(),

                        const SizedBox(height: 32),

                        // Image URL
                        _buildSectionHeader('Raffle Image (Optional)'),
                        const SizedBox(height: 16),
                        _buildImageUrlSection(),

                        const SizedBox(height: 48),

                        // Create Button
                        CustomButton(
                          text: 'Create Raffle',
                          onPressed: _isLoading ? null : () => _createRaffle(),
                          isLoading: _isLoading,
                          width: double.infinity,
                          icon: Icons.add_circle,
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      backgroundColor: AppTheme.black,
      title: Text(
        'Create Raffle',
        style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryGold),
      ),
      elevation: 0,
    );
  }

  Widget _buildDesktopHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: AppTheme.primaryGold),
          ),
          const SizedBox(width: 16),
          Text(
            'Create New Raffle',
            style: AppTheme.headingLarge.copyWith(color: AppTheme.primaryGold),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTheme.headingMedium.copyWith(color: AppTheme.white),
    );
  }

  Widget _buildBasicInfoSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          CustomTextField(
            controller: _titleController,
            label: 'Raffle Title',
            hint: 'Enter an attractive title for your raffle',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Title is required';
              }
              if (value.length < 5) {
                return 'Title must be at least 5 characters';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          CustomTextField(
            controller: _descriptionController,
            label: 'Description',
            hint: 'Describe what makes this raffle special',
            maxLines: 3,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Description is required';
              }
              if (value.length < 10) {
                return 'Description must be at least 10 characters';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          CustomTextField(
            controller: _maxEntriesController,
            label: 'Maximum Entries',
            hint: 'Maximum number of participants (e.g., 1000)',
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Maximum entries is required';
              }
              final number = int.tryParse(value);
              if (number == null || number <= 0) {
                return 'Please enter a valid number greater than 0';
              }
              if (number > 10000) {
                return 'Maximum entries cannot exceed 10,000';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDatesAndSettingsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Start Date
          _buildDatePicker(
            label: 'Start Date',
            selectedDate: _startDate,
            onDateSelected: (date) => setState(() => _startDate = date),
            validatorText: 'Start date is required',
          ),

          const SizedBox(height: 16),

          // End Date
          _buildDatePicker(
            label: 'End Date',
            selectedDate: _endDate,
            onDateSelected: (date) => setState(() => _endDate = date),
            validatorText: 'End date is required',
            firstDate: _startDate ?? DateTime.now(),
          ),

          const SizedBox(height: 16),

          // Info: All raffles are public
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryGold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primaryGold, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'All raffles are public and visible to everyone',
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Removed _buildEntryRequirementsSection - entry is always free now

  Widget _buildPrizeDetailsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          CustomTextField(
            controller: _prizeValueController,
            label: 'Prize Value',
            hint: 'e.g., \$50 Amazon Gift Card, \$100 Voucher',
            keyboardType: TextInputType.text,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Prize value is required';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          CustomTextField(
            controller: _prizeDescriptionController,
            label: 'Prize Description',
            hint: 'Describe the gift voucher details',
            maxLines: 3,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Prize description is required';
              }
              if (value.length < 10) {
                return 'Description must be at least 10 characters';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildImageUrlSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          CustomTextField(
            controller: _imageUrlController,
            label: 'Image URL',
            hint: 'Paste image URL here (e.g., https://example.com/image.jpg)',
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          Text(
            'Tip: Upload your image to a service like Imgur or use a direct image link',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
          if (_imageUrlController.text.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              height: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  _imageUrlController.text,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: AppTheme.black,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, color: AppTheme.red, size: 48),
                          const SizedBox(height: 8),
                          Text(
                            'Invalid Image URL',
                            style: AppTheme.bodyMedium.copyWith(color: AppTheme.red),
                          ),
                        ],
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: AppTheme.black,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryGold,
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? selectedDate,
    required Function(DateTime) onDateSelected,
    required String validatorText,
    DateTime? firstDate,
  }) {
    final effectiveFirstDate = firstDate ?? DateTime.now();
    return InkWell(
      onTap: () async {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? effectiveFirstDate,
          firstDate: effectiveFirstDate,
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: AppTheme.primaryGold,
                  surface: AppTheme.darkGrey,
                  onSurface: AppTheme.white,
                ),
              ),
              child: child!,
            );
          },
        );

        if (pickedDate != null) {
          final pickedTime = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(
              selectedDate ?? effectiveFirstDate,
            ),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: AppTheme.primaryGold,
                    surface: AppTheme.darkGrey,
                    onSurface: AppTheme.white,
                  ),
                ),
                child: child!,
              );
            },
          );

          if (pickedTime != null) {
            final combinedDateTime = DateTime(
              pickedDate.year,
              pickedDate.month,
              pickedDate.day,
              pickedTime.hour,
              pickedTime.minute,
            );
            onDateSelected(combinedDateTime);
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.grey.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: AppTheme.primaryGold),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTheme.labelMedium.copyWith(color: AppTheme.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedDate != null
                        ? _formatDateTime(selectedDate)
                        : 'Select date and time',
                    style: AppTheme.bodyMedium.copyWith(
                      color: selectedDate != null
                          ? AppTheme.white
                          : AppTheme.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down, color: AppTheme.primaryGold),
          ],
        ),
      ),
    );
  }

  /// Format DateTime to show date and time in readable format with AM/PM
  String _formatDateTime(DateTime dateTime) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    // Convert to 12-hour format
    final hour12 = dateTime.hour % 12;
    final hour = hour12 == 0 ? 12 : hour12;
    final amPm = dateTime.hour < 12 ? 'AM' : 'PM';
    final minute = dateTime.minute.toString().padLeft(2, '0');
    
    return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year} at ${hour}:${minute} $amPm';
  }

  Future<void> _createRaffle() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both start and end dates'),
          backgroundColor: AppTheme.red,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to create a raffle'),
          backgroundColor: AppTheme.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Prepare prize details for gift voucher
      final prizeDetails = <String, dynamic>{
        'type': 'gift_voucher',
        'value': _prizeValueController.text,
        'description': _prizeDescriptionController.text,
        'totalValue': _prizeValueController.text,
      };

      // Get image URL if provided
      final imageUrl = _imageUrlController.text.trim().isNotEmpty
          ? _imageUrlController.text.trim()
          : null;

      // Create the raffle (simplified - entry is always free)
      final raffleId = await RaffleService.createRaffle(
        creatorId: user.uid,
        creatorName: user.displayName ?? 'Anonymous',
        title: _titleController.text,
        description: _descriptionController.text,
        prizeDetails: prizeDetails,
        maxEntries: int.parse(_maxEntriesController.text),
        startDate: _startDate!,
        endDate: _endDate!,
        imageUrl: imageUrl,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Raffle created successfully!'),
          backgroundColor: AppTheme.green,
        ),
      );

      // Navigate back to raffle hub
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create raffle: $e'),
          backgroundColor: AppTheme.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Verify admin status with server-side check
  Future<bool> _verifyAdminStatus(AdminProvider adminProvider) async {
    try {
      // Refresh admin status first
      await adminProvider.refreshAdminStatus();
      
      // Double-check with provider
      if (!adminProvider.isAdmin) {
        return false;
      }

      // Additional server-side verification
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Check user role directly from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('USER')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return false;

      final userData = userDoc.data() as Map<String, dynamic>?;
      final role = userData?['role'] as String?;

      // Strict check: Only admin or super_admin (NOT vendor)
      return role == 'admin' || role == 'super_admin';
    } catch (e) {
      print('Error verifying admin status: $e');
      return false;
    }
  }
}
