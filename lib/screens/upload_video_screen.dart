import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

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

  Future<void> _pickVideo() async {
    setState(() => _isProcessing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        withData: true, // Pre-load the file data
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
    } finally {
      setState(() => _isProcessing = false);
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
    });

    try {
      // Show immediate feedback
      setState(() => _uploadProgress = 0.1);

      // Upload thumbnail first (smaller file)
      final thumbnailUrl = await _storage.uploadToR2(
        _thumbnailFile!.bytes!,
        'thumbnails/${DateTime.now().millisecondsSinceEpoch}_${_thumbnailFile!.name}',
        'image/jpeg',
      );

      setState(() => _uploadProgress = 0.2);

      // Upload video with progress
      final videoUrl = await _storage.uploadToR2(
        _videoFile!.bytes!,
        'videos/${DateTime.now().millisecondsSinceEpoch}_${_videoFile!.name}',
        'video/mp4',
        onProgress: (progress) {
          setState(() {
            // Scale progress from 20% to 90%
            _uploadProgress = 0.2 + (progress * 0.7);
          });
        },
      );

      // Save metadata
      setState(() => _uploadProgress = 0.9);
      await _storage.saveVideoMetadata(
        title: _titleController.text,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
      );

      setState(() => _uploadProgress = 1.0);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video uploaded successfully!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError('Upload failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
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
                  _isProcessing 
                    ? 'Processing...' 
                    : 'Uploading: ${(_uploadProgress * 100).toStringAsFixed(0)}%',
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