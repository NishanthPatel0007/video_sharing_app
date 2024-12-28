// lib/utils/error_handler.dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

class AppError implements Exception {
  final String message;
  final String? code;
  final dynamic details;
  final StackTrace? stackTrace;

  AppError(
    this.message, {
    this.code,
    this.details,
    this.stackTrace,
  });

  @override
  String toString() => 'AppError: $message ${code != null ? '($code)' : ''}';
}

class ErrorHandler {
  static void showError(BuildContext context, dynamic error) {
    String message = _getErrorMessage(error);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  static String _getErrorMessage(dynamic error) {
    if (error is AppError) {
      return error.message;
    }

    final message = error.toString().toLowerCase();

    // Network errors
    if (message.contains('socket')) {
      return AppConstants.networkError;
    }

    // Upload errors
    if (message.contains('upload') || message.contains('storage')) {
      return AppConstants.uploadError;
    }

    // Authentication errors
    if (message.contains('auth') || message.contains('permission')) {
      return AppConstants.authError;
    }

    // Playback errors
    if (message.contains('video') || message.contains('media')) {
      return AppConstants.playbackError;
    }

    return 'An unexpected error occurred';
  }

  static Future<T> handleFuture<T>(
    Future<T> future,
    BuildContext context, {
    String? loadingMessage,
    bool showSuccess = false,
  }) async {
    try {
      final result = await future;
      
      if (showSuccess && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Operation completed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      return result;
    } catch (e, stackTrace) {
      if (context.mounted) {
        showError(context, AppError(
          _getErrorMessage(e),
          stackTrace: stackTrace,
          details: e,
        ));
      }
      rethrow;
    }
  }

  static void logError(
    dynamic error,
    StackTrace? stackTrace, {
    String? context,
    Map<String, dynamic>? extra,
  }) {
    // Add your logging service here (e.g., Firebase Crashlytics)
    print('Error${context != null ? ' in $context' : ''}: $error');
    if (stackTrace != null) print('StackTrace: $stackTrace');
    if (extra != null) print('Extra info: $extra');
  }

  static Future<void> showErrorDialog(
    BuildContext context,
    String title,
    String message, {
    VoidCallback? onRetry,
  }) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2940),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          if (onRetry != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onRetry();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
              ),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  static Widget errorWidget(String message, {VoidCallback? onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Platform specific error checks
  static bool isNetworkError(dynamic error) {
    final message = error.toString().toLowerCase();
    return message.contains('socket') ||
           message.contains('network') ||
           message.contains('connection') ||
           message.contains('internet');
  }

  static bool isStorageError(dynamic error) {
    final message = error.toString().toLowerCase();
    return message.contains('storage') ||
           message.contains('upload') ||
           message.contains('file') ||
           message.contains('disk');
  }

  static bool isPermissionError(dynamic error) {
    final message = error.toString().toLowerCase();
    return message.contains('permission') ||
           message.contains('denied') ||
           message.contains('unauthorized');
  }

  static bool isPlaybackError(dynamic error) {
    final message = error.toString().toLowerCase();
    return message.contains('video') ||
           message.contains('media') ||
           message.contains('player') ||
           message.contains('playback');
  }

  // Retry mechanism
  static Future<T> withRetry<T>({
    required Future<T> Function() operation,
    int maxAttempts = 3,
    Duration delay = const Duration(seconds: 1),
    bool Function(Exception)? shouldRetry,
  }) async {
    int attempts = 0;
    while (true) {
      try {
        attempts++;
        return await operation();
      } on Exception catch (e) {
        if (attempts >= maxAttempts || 
            (shouldRetry != null && !shouldRetry(e))) {
          rethrow;
        }
        await Future.delayed(delay * attempts);
      }
    }
  }

  // Clipboard error handling
  static Future<bool> handleClipboardOperation(
    Future<void> Function() operation
  ) async {
    try {
      await operation();
      return true;
    } catch (e) {
      print('Clipboard operation failed: $e');
      return false;
    }
  }

  // File validation errors
  static String? validateFileSize(int size, int maxSize) {
    if (size > maxSize) {
      return 'File size (${(size / 1024 / 1024).toStringAsFixed(1)}MB) exceeds maximum allowed size of ${(maxSize / 1024 / 1024).toStringAsFixed(1)}MB';
    }
    return null;
  }

  static String? validateFileType(String type, List<String> allowedTypes) {
    if (!allowedTypes.contains(type.toLowerCase())) {
      return 'File type $type is not supported. Allowed types: ${allowedTypes.join(", ")}';
    }
    return null;
  }
}