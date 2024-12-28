// lib/widgets/share_widget.dart
import 'package:flutter/material.dart';

import '../services/video_url_service.dart';

class ShareWidget extends StatefulWidget {
  final String videoId;
  final bool isLoading;
  final String? shareUrl;

  const ShareWidget({
    Key? key,
    required this.videoId,
    required this.shareUrl,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<ShareWidget> createState() => _ShareWidgetState();
}

class _ShareWidgetState extends State<ShareWidget> {
  final VideoUrlService _urlService = VideoUrlService();
  bool _isCopying = false;

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
            'COPY TO CLIPBOARD',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B2C),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF3D3950),
                width: 1,
              ),
            ),
            child: SelectableText(
              widget.shareUrl ?? 'https://for10cloud.com/v/...',
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: widget.isLoading || _isCopying
                ? null
                : () async {
                    setState(() => _isCopying = true);
                    try {
                      await _urlService.copyToClipboard(
                        widget.videoId,
                        context,
                      );
                    } finally {
                      if (mounted) {
                        setState(() => _isCopying = false);
                      }
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8257E5),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              minimumSize: const Size(double.infinity, 48),
            ),
            child: _isCopying || widget.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Copy',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}