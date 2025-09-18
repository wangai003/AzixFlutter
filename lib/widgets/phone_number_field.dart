import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';
import '../theme/app_theme.dart';

class PhoneNumberField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final Function(PhoneNumber)? onChanged;
  final bool autofocus;
  final FocusNode? focusNode;
  final String? initialCountryCode;

  const PhoneNumberField({
    Key? key,
    required this.label,
    this.hint,
    required this.controller,
    this.validator,
    this.onChanged,
    this.autofocus = false,
    this.focusNode,
    this.initialCountryCode,
  }) : super(key: key);

  @override
  State<PhoneNumberField> createState() => _PhoneNumberFieldState();
}

class _PhoneNumberFieldState extends State<PhoneNumberField> {
  String? _errorText;

  @override
  Widget build(BuildContext context) {
    return IntlPhoneField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      initialCountryCode: widget.initialCountryCode ?? 'US',
      showCountryFlag: true,
      showDropdownIcon: true,
      dropdownIconPosition: IconPosition.trailing,
      flagsButtonPadding: const EdgeInsets.symmetric(horizontal: 8),
      dropdownIcon: Icon(
        Icons.arrow_drop_down,
        color: AppTheme.primaryGold,
      ),
      style: AppTheme.bodyMedium.copyWith(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.white
            : AppTheme.black,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint ?? 'Enter your phone number',
        labelStyle: AppTheme.bodyMedium.copyWith(
          color: AppTheme.grey,
        ),
        hintStyle: AppTheme.bodyMedium.copyWith(
          color: AppTheme.grey.withOpacity(0.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppTheme.grey.withOpacity(0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppTheme.grey.withOpacity(0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppTheme.primaryGold,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.red.withOpacity(0.5),
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.red,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkGrey.withOpacity(0.3)
            : Colors.grey.withOpacity(0.1),
        errorText: _errorText,
      ),
      languageCode: "en",
      onChanged: (phone) {
        // Clear error when user starts typing
        if (_errorText != null) {
          setState(() {
            _errorText = null;
          });
        }
        widget.onChanged?.call(phone);
      },
      validator: (phone) {
        if (phone == null || phone.number.isEmpty) {
          setState(() {
            _errorText = 'Phone number is required';
          });
          return 'Phone number is required';
        }
        if (phone.number.length < 7) {
          setState(() {
            _errorText = 'Please enter a valid phone number';
          });
          return 'Please enter a valid phone number';
        }
        // Additional validation can be added here
        if (widget.validator != null) {
          final customError = widget.validator!(phone.completeNumber);
          if (customError != null) {
            setState(() {
              _errorText = customError;
            });
            return customError;
          }
        }
        setState(() {
          _errorText = null;
        });
        return null;
      },
    );
  }
}
