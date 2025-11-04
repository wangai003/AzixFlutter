import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
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
  final _detailedDescriptionController = TextEditingController();
  final _maxEntriesController = TextEditingController();
  final _prizeValueController = TextEditingController();
  final _prizeDescriptionController = TextEditingController();
  final _entryCostController = TextEditingController();
  final _minBalanceController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isPublic = true;
  EntryRequirement _entryType = EntryRequirement.free;
  File? _selectedImage;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _detailedDescriptionController.dispose();
    _maxEntriesController.dispose();
    _prizeValueController.dispose();
    _prizeDescriptionController.dispose();
    _entryCostController.dispose();
    _minBalanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isTablet = ResponsiveLayout.isTablet(context);

    // Check if user is admin
    if (!adminProvider.isAdmin) {
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
                color: AppTheme.primaryGold,
                size: 64,
              ),
              const SizedBox(height: 24),
              Text(
                'Admin Access Required',
                style: AppTheme.headingLarge.copyWith(color: AppTheme.white),
              ),
              const SizedBox(height: 16),
              Text(
                'Only administrators can create raffles.',
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
                    _buildSectionHeader('Basic Information'),
                    const SizedBox(height: 16),
                    _buildBasicInfoSection(),

                    const SizedBox(height: 32),

                    // Dates and Settings
                    _buildSectionHeader('Dates & Settings'),
                    const SizedBox(height: 16),
                    _buildDatesAndSettingsSection(),

                    const SizedBox(height: 32),

                    // Entry Requirements
                    _buildSectionHeader('Entry Requirements'),
                    const SizedBox(height: 16),
                    _buildEntryRequirementsSection(),

                    const SizedBox(height: 32),

                    // Prize Details
                    _buildSectionHeader('Prize Details'),
                    const SizedBox(height: 16),
                    _buildPrizeDetailsSection(),

                    const SizedBox(height: 32),

                    // Image Upload
                    _buildSectionHeader('Raffle Image (Optional)'),
                    const SizedBox(height: 16),
                    _buildImageUploadSection(),

                    const SizedBox(height: 48),

                    // Create Button
                    CustomButton(
                      text: 'Create Raffle',
                      onPressed: _isLoading ? null : () => _createRaffle(),
                      isLoading: _isLoading,
                      width: double.infinity,
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
            controller: _detailedDescriptionController,
            label: 'Detailed Description (Optional)',
            hint: 'Provide additional details, rules, or terms',
            maxLines: 5,
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

          const SizedBox(height: 24),

          // Public/Private Toggle
          Row(
            children: [
              Text(
                'Make Raffle Public',
                style: AppTheme.bodyLarge.copyWith(color: AppTheme.white),
              ),
              const Spacer(),
              Switch(
                value: _isPublic,
                onChanged: (value) => setState(() => _isPublic = value),
                activeColor: AppTheme.primaryGold,
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            _isPublic
                ? 'Anyone can see and enter this raffle'
                : 'Only invited users can see and enter this raffle',
            style: AppTheme.bodySmall.copyWith(color: AppTheme.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryRequirementsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Entry Type
          Text(
            'Entry Type',
            style: AppTheme.labelLarge.copyWith(color: AppTheme.white),
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: EntryRequirement.values.map((type) {
              return ChoiceChip(
                label: Text(
                  _getEntryTypeDisplayName(type),
                  style: AppTheme.bodyMedium.copyWith(
                    color: _entryType == type ? AppTheme.black : AppTheme.white,
                  ),
                ),
                selected: _entryType == type,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _entryType = type);
                  }
                },
                selectedColor: AppTheme.primaryGold,
                backgroundColor: AppTheme.grey.withOpacity(0.2),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Conditional fields based on entry type
          if (_entryType == EntryRequirement.purchase)
            CustomTextField(
              controller: _entryCostController,
              label: 'Entry Cost (AKOFA)',
              hint: 'Amount of AKOFA required to enter',
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (_entryType == EntryRequirement.purchase) {
                  if (value == null || value.isEmpty) {
                    return 'Entry cost is required';
                  }
                  final cost = double.tryParse(value);
                  if (cost == null || cost <= 0) {
                    return 'Please enter a valid amount';
                  }
                }
                return null;
              },
            ),

          if (_entryType == EntryRequirement.walletBalance)
            CustomTextField(
              controller: _minBalanceController,
              label: 'Minimum Balance (AKOFA)',
              hint: 'Minimum AKOFA balance required',
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (_entryType == EntryRequirement.walletBalance) {
                  if (value == null || value.isEmpty) {
                    return 'Minimum balance is required';
                  }
                  final balance = double.tryParse(value);
                  if (balance == null || balance <= 0) {
                    return 'Please enter a valid amount';
                  }
                }
                return null;
              },
            ),
        ],
      ),
    );
  }

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
            label: 'Prize Value (AKOFA)',
            hint: 'Total value of the prize in AKOFA',
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Prize value is required';
              }
              final prizeValue = double.tryParse(value);
              if (prizeValue == null || prizeValue <= 0) {
                return 'Please enter a valid prize value';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          CustomTextField(
            controller: _prizeDescriptionController,
            label: 'Prize Description',
            hint: 'Describe what the winner will receive',
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

  Widget _buildImageUploadSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          if (_selectedImage != null)
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: FileImage(_selectedImage!),
                  fit: BoxFit.cover,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      onPressed: () => setState(() => _selectedImage = null),
                      icon: const Icon(Icons.close, color: AppTheme.white),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.black.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.grey.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image, color: AppTheme.grey, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    'No image selected',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.grey),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.primaryGold),
                    foregroundColor: AppTheme.primaryGold,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.primaryGold),
                    foregroundColor: AppTheme.primaryGold,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
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
                        ? '${selectedDate.day}/${selectedDate.month}/${selectedDate.year} ${selectedDate.hour}:${selectedDate.minute.toString().padLeft(2, '0')}'
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() => _selectedImage = File(pickedFile.path));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: AppTheme.red,
        ),
      );
    }
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
      // Prepare entry requirements
      final entryRequirements = <String, dynamic>{
        'type': _entryType.toString().split('.').last,
      };

      if (_entryType == EntryRequirement.purchase &&
          _entryCostController.text.isNotEmpty) {
        entryRequirements['cost'] = double.parse(_entryCostController.text);
      }

      if (_entryType == EntryRequirement.walletBalance &&
          _minBalanceController.text.isNotEmpty) {
        entryRequirements['minBalance'] = double.parse(
          _minBalanceController.text,
        );
      }

      // Prepare prize details
      final prizeDetails = <String, dynamic>{
        'type': 'akofa',
        'value': double.parse(_prizeValueController.text),
        'description': _prizeDescriptionController.text,
      };

      // Upload image if selected
      String? imageUrl;
      if (_selectedImage != null) {
        // TODO: Implement image upload to Firebase Storage
        // imageUrl = await RaffleService.uploadRaffleImage(...);
      }

      // Create the raffle
      final raffleId = await RaffleService.createRaffle(
        creatorId: user.uid,
        creatorName: user.displayName ?? 'Anonymous',
        title: _titleController.text,
        description: _descriptionController.text,
        entryRequirements: entryRequirements,
        prizeDetails: prizeDetails,
        maxEntries: int.parse(_maxEntriesController.text),
        startDate: _startDate!,
        endDate: _endDate!,
        detailedDescription: _detailedDescriptionController.text.isNotEmpty
            ? _detailedDescriptionController.text
            : null,
        imageUrl: imageUrl,
        isPublic: _isPublic,
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

  String _getEntryTypeDisplayName(EntryRequirement type) {
    switch (type) {
      case EntryRequirement.free:
        return 'Free';
      case EntryRequirement.purchase:
        return 'Purchase';
      case EntryRequirement.referral:
        return 'Referral';
      case EntryRequirement.socialShare:
        return 'Social Share';
      case EntryRequirement.walletBalance:
        return 'Wallet Balance';
    }
  }
}
