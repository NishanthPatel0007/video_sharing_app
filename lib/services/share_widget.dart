import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/video_url_service.dart';
import '../utils/platform_helper.dart';

class ShareWidget extends StatefulWidget {
  final String videoId;
  final String? shareUrl;
  final Function(String url)? onUrlGenerated;

  const ShareWidget({
    Key? key,
    required this.videoId,
    this.shareUrl,
    this.onUrlGenerated,
  }) : super(key: key);

  @override
  State<ShareWidget> createState() => _ShareWidgetState();
}

class _ShareWidgetState extends State<ShareWidget> {
  final VideoUrlService _urlService = VideoUrlService();
  bool _isCopying = false;
  bool _hasError = false;
  String? _errorMessage;
  String? _currentUrl;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.shareUrl;
    if (_currentUrl == null) {
      _generateShareUrl();
    }
  }

  Future<void> _generateShareUrl() async {
    try {
      setState(() {
        _hasError = false;
        _errorMessage = null;
      });

      final url = await _urlService.getShareUrl(widget.videoId);
      
      if (mounted) {
        setState(() {
          _currentUrl = url;
        });
        widget.onUrlGenerated?.call(url ?? '');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to generate share URL';
        });
      }
    }
  }

  Future<void> _copyToClipboard() async {
    if (_currentUrl == null || _isCopying) return;

    setState(() {
      _isCopying = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      // Try the standard clipboard API first
      await Clipboard.setData(ClipboardData(text: _currentUrl!));
      _showSuccessSnackbar();
    } catch (e1) {
      // If standard clipboard fails, try platform-specific methods
      try {
        final success = await _platformSpecificCopy(_currentUrl!);
        if (success) {
          _showSuccessSnackbar();
        } else {
          _handleCopyError();
        }
      } catch (e2) {
        _handleCopyError();
      }
    } finally {
      if (mounted) {
        setState(() => _isCopying = false);
      }
    }
  }

  Future<bool> _platformSpecificCopy(String text) async {
    if (PlatformHelper.isMobileBrowser) {
      // Mobile browser specific handling
      final textarea = html.TextAreaElement()
        ..value = text
        ..style.position = 'fixed'
        ..style.left = '-9999px'
        ..style.opacity = '0';
      html.document.body?.append(textarea);

      try {
        textarea.select();
        textarea.setSelectionRange(0, text.length);
        final result = html.document.execCommand('copy');
        textarea.remove();
        return result;
      } catch (e) {
        textarea.remove();
        return false;
      }
    } else if (PlatformHelper.isSafariBrowser) {
      // Safari specific handling
      final permission = await html.window.navigator.permissions?.query({
        'name': 'clipboard-write'
      });
      
      if (permission?.state == 'granted') {
        await html.window.navigator.clipboard?.writeText(text);
        return true;
      }
      return false;
    }

    return false;
  }

  void _handleCopyError() {
    setState(() {
      _hasError = true;
      _errorMessage = 'Failed to copy to clipboard';
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Unable to copy. Please try selecting and copying manually.'),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Select All',
          textColor: Colors.white,
          onPressed: () {
            // Make URL selectable when automatic copy fails
            final controller = TextEditingController(text: _currentUrl);
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Share URL'),
                content: TextField(
                  controller: controller,
                  readOnly: true,
                  onTap: () => controller.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: controller.text.length,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showSuccessSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2940),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF3D3950),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'SHARE VIDEO',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          
          // URL Display
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B2C),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _hasError ? Colors.red : const Color(0xFF3D3950),
                width: 1,
              ),
            ),
            child: SelectableText(
              _currentUrl ?? 'Generating URL...',
              style: TextStyle(
                color: _hasError ? Colors.red : Colors.white70,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
          ),

          if (_hasError && _errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 12),

          // Copy Button
          ElevatedButton(
            onPressed: _currentUrl == null || _isCopying 
                ? null 
                : _copyToClipboard,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8257E5),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              minimumSize: const Size(double.infinity, 48),
            ),
            child: _isCopying
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.content_copy, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Copy Link',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
          ),

          // Retry Button for Errors
          if (_hasError) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _generateShareUrl,
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}