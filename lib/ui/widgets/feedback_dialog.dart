import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_error.dart';
import '../../services/user_feedback_service.dart';
import '../theme/app_theme.dart';

/// Dialog for collecting user feedback about issues
class FeedbackDialog extends ConsumerStatefulWidget {
  final AppError? relatedError;
  final String? initialTitle;
  final String? initialDescription;
  final FeedbackCategory? initialCategory;

  const FeedbackDialog({
    super.key,
    this.relatedError,
    this.initialTitle,
    this.initialDescription,
    this.initialCategory,
  });

  @override
  ConsumerState<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends ConsumerState<FeedbackDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();

  FeedbackCategory _selectedCategory = FeedbackCategory.other;
  FeedbackSeverity _selectedSeverity = FeedbackSeverity.medium;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize form with provided data
    if (widget.initialTitle != null) {
      _titleController.text = widget.initialTitle!;
    }
    if (widget.initialDescription != null) {
      _descriptionController.text = widget.initialDescription!;
    }
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
    
    // Set category and severity based on related error
    if (widget.relatedError != null) {
      _selectedCategory = _mapErrorCategoryToFeedbackCategory(widget.relatedError!.category);
      _selectedSeverity = _mapErrorSeverityToFeedbackSeverity(widget.relatedError!.severity);
      
      if (_titleController.text.isEmpty) {
        _titleController.text = 'Issue with ${widget.relatedError!.category.toString().split('.').last}';
      }
      
      if (_descriptionController.text.isEmpty) {
        _descriptionController.text = widget.relatedError!.userMessage;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.feedback_outlined,
                      color: AppTheme.primaryBlue,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Report an Issue',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Form content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title field
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Issue Title *',
                            hintText: 'Brief description of the issue',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a title for the issue';
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Category dropdown
                        DropdownButtonFormField<FeedbackCategory>(
                          value: _selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category *',
                            border: OutlineInputBorder(),
                          ),
                          items: FeedbackCategory.values.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(_getCategoryDisplayName(category)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedCategory = value;
                              });
                            }
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Severity dropdown
                        DropdownButtonFormField<FeedbackSeverity>(
                          value: _selectedSeverity,
                          decoration: const InputDecoration(
                            labelText: 'Severity *',
                            border: OutlineInputBorder(),
                          ),
                          items: FeedbackSeverity.values.map((severity) {
                            return DropdownMenuItem(
                              value: severity,
                              child: Row(
                                children: [
                                  Icon(
                                    _getSeverityIcon(severity),
                                    color: _getSeverityColor(severity),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(_getSeverityDisplayName(severity)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedSeverity = value;
                              });
                            }
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Description field
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Description *',
                            hintText: 'Please describe the issue in detail...',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 5,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please provide a description of the issue';
                            }
                            if (value.trim().length < 10) {
                              return 'Please provide a more detailed description';
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Contact information section
                        Text(
                          'Contact Information (Optional)',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Provide your contact information if you\'d like us to follow up on this issue.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Email field
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            hintText: 'your.email@example.com',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                return 'Please enter a valid email address';
                              }
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Additional contact field
                        TextFormField(
                          controller: _contactController,
                          decoration: const InputDecoration(
                            labelText: 'Additional Contact Info',
                            hintText: 'Phone number, Discord, etc.',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.contact_phone_outlined),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Information note
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue[600],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'This report will include diagnostic information to help us resolve the issue. No personal data will be collected without your consent.',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitFeedback,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Submit Report'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Get the user feedback service (you'll need to provide this through a provider)
      // For now, we'll simulate the submission
      
      await Future.delayed(const Duration(seconds: 1)); // Simulate API call
      
      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Feedback submitted successfully'),
              ],
            ),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Text('Failed to submit feedback: $e'),
              ],
            ),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _getCategoryDisplayName(FeedbackCategory category) {
    switch (category) {
      case FeedbackCategory.connectionIssue:
        return 'Connection Issue';
      case FeedbackCategory.performanceIssue:
        return 'Performance Issue';
      case FeedbackCategory.configurationProblem:
        return 'Configuration Problem';
      case FeedbackCategory.uiProblem:
        return 'User Interface Problem';
      case FeedbackCategory.featureRequest:
        return 'Feature Request';
      case FeedbackCategory.bug:
        return 'Bug Report';
      case FeedbackCategory.other:
        return 'Other';
    }
  }

  String _getSeverityDisplayName(FeedbackSeverity severity) {
    switch (severity) {
      case FeedbackSeverity.low:
        return 'Low - Minor inconvenience';
      case FeedbackSeverity.medium:
        return 'Medium - Affects functionality';
      case FeedbackSeverity.high:
        return 'High - Major problem';
      case FeedbackSeverity.critical:
        return 'Critical - App unusable';
    }
  }

  IconData _getSeverityIcon(FeedbackSeverity severity) {
    switch (severity) {
      case FeedbackSeverity.low:
        return Icons.info_outline;
      case FeedbackSeverity.medium:
        return Icons.warning_amber_outlined;
      case FeedbackSeverity.high:
        return Icons.error_outline;
      case FeedbackSeverity.critical:
        return Icons.dangerous_outlined;
    }
  }

  Color _getSeverityColor(FeedbackSeverity severity) {
    switch (severity) {
      case FeedbackSeverity.low:
        return Colors.blue[600]!;
      case FeedbackSeverity.medium:
        return AppTheme.warningOrange;
      case FeedbackSeverity.high:
        return AppTheme.errorRed;
      case FeedbackSeverity.critical:
        return Colors.red[800]!;
    }
  }

  FeedbackCategory _mapErrorCategoryToFeedbackCategory(ErrorCategory errorCategory) {
    switch (errorCategory) {
      case ErrorCategory.network:
        return FeedbackCategory.connectionIssue;
      case ErrorCategory.configuration:
        return FeedbackCategory.configurationProblem;
      case ErrorCategory.permission:
      case ErrorCategory.platform:
      case ErrorCategory.authentication:
      case ErrorCategory.system:
        return FeedbackCategory.bug;
      case ErrorCategory.unknown:
        return FeedbackCategory.other;
    }
  }

  FeedbackSeverity _mapErrorSeverityToFeedbackSeverity(ErrorSeverity errorSeverity) {
    switch (errorSeverity) {
      case ErrorSeverity.critical:
        return FeedbackSeverity.critical;
      case ErrorSeverity.high:
        return FeedbackSeverity.high;
      case ErrorSeverity.medium:
        return FeedbackSeverity.medium;
      case ErrorSeverity.low:
        return FeedbackSeverity.low;
    }
  }
}

/// Simple feedback button widget
class FeedbackButton extends StatelessWidget {
  final AppError? relatedError;
  final String? buttonText;
  final IconData? icon;

  const FeedbackButton({
    super.key,
    this.relatedError,
    this.buttonText,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => _showFeedbackDialog(context),
      icon: Icon(icon ?? Icons.feedback_outlined),
      label: Text(buttonText ?? 'Report Issue'),
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => FeedbackDialog(relatedError: relatedError),
    );
  }
}