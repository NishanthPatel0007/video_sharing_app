import 'dart:io' show Platform;

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../screens/upload_service.dart';
import '../services/storage_service.dart';
import '../services/video_format_handler.dart';

class UploadVideoScreen extends StatefulWidget {
  const UploadVideoScreen({Key? key}) : super(key: key);

  @override
  _UploadVideoScreenState createState() => _UploadVideoScreenState();
}

class _UploadVideoScreenState extends State<UploadVideoScreen> {
  final _titleController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final StorageService _storage = StorageService();
  final _auth = FirebaseAuth.instance;
  
  bool _isUploading = false;
  bool _isProcessing = false;
  double _uploadProgress = 0;
  String? _selectedVideoName;
  String? _selectedThumbnailName;
  String? _processingStatus;
  String _selectedQuality = 'medium';
  bool _generateHLS = false;
  PlatformFile? _videoFile;
  PlatformFile? _thumbnailFile;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _initializeUpload();
  }

  void _checkAuth() {
    if (_auth.currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
    }
  }

  Future<void> _initializeUpload() async {
    _generateHLS = !kIsWeb && Platform.isIOS;
  }

Future<void> _pickVideo() async {
  if (_isUploading) return;
  
  setState(() => _isProcessing = true);
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
      withData: true,
      allowedExtensions: VideoFormatHandler.getSupportedFormats(),
    );

    if (result != null) {
      // Validate file size
      if (result.files.first.size > UploadService.maxVideoSize) {
        _showError('Video file must be less than ${UploadService.maxVideoSize ~/ (1024 * 1024)}MB');
        return;
      }

      // Validate file format
      final extension = result.files.first.name.split('.').last.toLowerCase();
      if (!VideoFormatHandler.isValidFormat('video/$extension')) {  // Changed this line
        _showError('Unsupported video format');
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

Future<void> _pickThumbnail() async {
  if (_isUploading) return;

  setState(() => _isProcessing = true);
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );

    if (result != null) {
      if (result.files.first.size > UploadService.maxThumbnailSize) {
        _showError('Thumbnail must be less than ${UploadService.maxThumbnailSize ~/ (1024 * 1024)}MB');
        return;
      }

      setState(() {
        _thumbnailFile = result.files.first;
        _selectedThumbnailName = result.files.first.name;
      });
    }
  } catch (e) {
    _showError('Error selecting thumbnail: $e');
  } finally {
    setState(() => _isProcessing = false);
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
      _processingStatus = 'Initializing upload...';
    });

    try {
      final uploadFormat = VideoFormatHandler.getUploadFormat(
        fileName: _videoFile!.name,
        fileSize: _videoFile!.size,
        generateHLS: _generateHLS,
      );

      await _storage.uploadVideoWithMetadata(
        title: _titleController.text,
        videoBytes: _videoFile!.bytes!,
        videoFileName: _videoFile!.name,
        thumbnailBytes: _thumbnailFile!.bytes!,
        thumbnailFileName: _thumbnailFile!.name,
        quality: _selectedQuality,
        generateHLS: uploadFormat['generateHLS'],
        onProgress: (progress) {
          setState(() {
            _uploadProgress = progress;
          });
        },
        onStatusUpdate: (status) {
          setState(() {
            _processingStatus = status;
          });
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video uploaded successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError('Upload failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _processingStatus = null;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload New Video'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isUploading ? null : () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Video Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter a title' : null,
                enabled: !_isUploading,
              ),
              const SizedBox(height: 24),

              // Quality Selection
              DropdownButtonFormField<String>(
                value: _selectedQuality,
                decoration: const InputDecoration(
                  labelText: 'Video Quality',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.high_quality),
                ),
                items: const [
                  DropdownMenuItem(value: 'high', child: Text('High Quality')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium Quality')),
                  DropdownMenuItem(value: 'low', child: Text('Low Quality')),
                ],
                onChanged: _isUploading ? null : (value) {
                  setState(() => _selectedQuality = value!);
                },
              ),
              const SizedBox(height: 24),

              // File Selection Cards
              _buildFileCard(
                'Video File',
                _selectedVideoName,
                Icons.video_library,
                _isUploading ? null : _pickVideo,
              ),
              const SizedBox(height: 16),
              _buildFileCard(
                'Thumbnail',
                _selectedThumbnailName,
                Icons.image,
                _isUploading ? null : _pickThumbnail,
              ),
              const SizedBox(height: 24),

              if (_isUploading || _isProcessing) ...[
                LinearProgressIndicator(value: _uploadProgress),
                const SizedBox(height: 8),
                Text(
                  _processingStatus ?? 'Processing...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
              ],

              ElevatedButton.icon(
                onPressed: (_isUploading || _isProcessing) ? null : _uploadVideo,
                icon: const Icon(Icons.cloud_upload),
                label: Text(_isUploading ? 'Uploading...' : 'Upload Video'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),

              if (_videoFile != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Selected file size: ${(_videoFile!.size / (1024 * 1024)).toStringAsFixed(2)} MB',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileCard(
    String title,
    String? selectedFileName,
    IconData icon,
    VoidCallback? onSelect,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              selectedFileName ?? 'No file selected',
              style: TextStyle(
                color: selectedFileName != null ? Colors.green : Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onSelect,
              icon: Icon(icon),
              label: Text('Select $title'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }
}