import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/storage_service.dart';

class UploadVideoScreen extends StatefulWidget {
  const UploadVideoScreen({Key? key}) : super(key: key);

  @override
  _UploadVideoScreenState createState() => _UploadVideoScreenState();
}

class _UploadVideoScreenState extends State<UploadVideoScreen> {
  final _titleController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final StorageService _storage = StorageService();
  
  bool _isUploading = false;
  double _uploadProgress = 0;
  String? _selectedVideoName;
  String? _selectedThumbnailName;
  PlatformFile? _videoFile;
  PlatformFile? _thumbnailFile;
  bool _isProcessing = false;
  String? _shareUrl;
  Uint8List? _thumbnailPreview;

  Future<void> _pickVideo() async {
    setState(() => _isProcessing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        withData: true,
      );

      if (result != null) {
        if (result.files.first.size > 500 * 1024 * 1024) {
          _showError('Video file must be less than 500MB');
          return;
        }

        setState(() {
          _videoFile = result.files.first;
          _selectedVideoName = result.files.first.name;
        });
      }
    } catch (e) {
      _showError('Error selecting video: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _clearVideo() {
    if (!_isUploading) {
      setState(() {
        _videoFile = null;
        _selectedVideoName = null;
      });
    }
  }

  Future<void> _pickThumbnail() async {
    setState(() => _isProcessing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result != null) {
        setState(() {
          _thumbnailFile = result.files.first;
          _selectedThumbnailName = result.files.first.name;
          _thumbnailPreview = result.files.first.bytes;
        });
      }
    } catch (e) {
      _showError('Error selecting thumbnail: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _clearThumbnail() {
    if (!_isUploading) {
      setState(() {
        _thumbnailFile = null;
        _selectedThumbnailName = null;
        _thumbnailPreview = null;
      });
    }
  }

  Future<void> _uploadVideo() async {
    if (!_formKey.currentState!.validate()) return;
    if (_videoFile == null || _thumbnailFile == null) {
      _showError('Please select both video and thumbnail files');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      setState(() => _uploadProgress = 0.1);

      final thumbnailUrl = await _storage.uploadToR2(
        _thumbnailFile!.bytes!,
        'thumbnails/${DateTime.now().millisecondsSinceEpoch}_${_thumbnailFile!.name}',
        'image/jpeg',
      );

      setState(() => _uploadProgress = 0.2);

      final videoUrl = await _storage.uploadToR2(
        _videoFile!.bytes!,
        'videos/${DateTime.now().millisecondsSinceEpoch}_${_videoFile!.name}',
        'video/mp4',
        onProgress: (progress) {
          setState(() {
            _uploadProgress = 0.2 + (progress * 0.7);
          });
        },
      );

      setState(() => _uploadProgress = 0.9);
      
      _shareUrl = await _storage.saveVideoMetadata(
        title: _titleController.text,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
      );

      setState(() => _uploadProgress = 1.0);

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      _showError('Upload failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1633),
        title: const Text(
          'Upload Successful',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your video share URL:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2D2940),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF8257E5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SelectableText(
                    _shareUrl != null 
                        ? 'https://for10cloud.com/v/${_shareUrl!.split('/').last}'
                        : 'https://for10cloud.com/v/...',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_shareUrl != null) ...[
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (_shareUrl != null) {
                final url = 'https://for10cloud.com/v/${_shareUrl!.split('/').last}';
                await Clipboard.setData(ClipboardData(text: url));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('URL copied to clipboard!'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
            ),
            child: const Text('Copy URL'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF8257E5),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1B2C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2940),
        elevation: 0,
        title: const Text(
          'Upload New Video',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _isUploading ? null : () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Video Title',
                    hintStyle: const TextStyle(color: Colors.white54),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF8257E5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF8257E5)),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF2D2940),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Please enter a title' : null,
                  enabled: !_isUploading,
                ),
                
                const SizedBox(height: 24),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 70/78,
                        child: _buildSelectionBox(
                          'Select Video',
                          _selectedVideoName,
                          _videoFile?.size,
                          _pickVideo,
                          _clearVideo,
                          isVideo: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 70/78,
                        child: _buildSelectionBox(
                          'Select Thumbnail',
                          _selectedThumbnailName,
                          _thumbnailFile?.size,
                          _pickThumbnail,
                          _clearThumbnail,
                          preview: _thumbnailPreview,
                          isVideo: false,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                if (_isUploading || _isProcessing) ...[
                  LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: const Color(0xFF2D2940),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8257E5)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isProcessing 
                      ? 'Processing...' 
                      : 'Uploading: ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                FilledButton(
                  onPressed: (_isUploading || _isProcessing) ? null : _uploadVideo,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF8257E5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _isUploading ? 'Uploading...' : 'Upload Video',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionBox(
    String label,
    String? selectedFile,
    int? fileSize,
    VoidCallback onSelect,
    VoidCallback onClear, {
    bool isVideo = false,
    Uint8List? preview,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2D2940),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF8257E5), width: 1),
      ),
      child: Stack(
        children: [
          if (selectedFile != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isVideo)
                    Container(
                      color: Colors.black87,
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_outline,
                          size: 40,
                          color: Colors.white70,
                        ),
                      ),
                    )
                  else if (preview != null)
                    Image.memory(
                      preview,
                      fit: BoxFit.cover,
                    )
                  else
                    Container(
                      color: const Color(0xFF1E1633),
                      child: const Center(
                        child: Icon(
                          Icons.image,
                          size: 40,
                          color: Colors.white70,
                        ),
                      ),
                    ),

                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                        stops: const [0.0, 0.2, 0.8, 1.0],
                        ),
                    ),
                  ),

                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          selectedFile,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (fileSize != null)
                          Text(
                            _formatFileSize(fileSize),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Center(
              child: FilledButton(
                onPressed: onSelect,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8257E5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          
          if (selectedFile != null)
            Positioned(
              right: 4,
              top: 4,
              child: IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: onClear,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(4),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }
}