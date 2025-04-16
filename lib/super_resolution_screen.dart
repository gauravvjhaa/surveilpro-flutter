import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:surveilpro/model_types.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'model_manager.dart';
import 'super_resolution_processor.dart';
import 'settings_screen.dart';

enum MediaType { image, video }

class SuperResolutionScreen extends StatefulWidget {
  const SuperResolutionScreen({Key? key}) : super(key: key);

  @override
  State<SuperResolutionScreen> createState() => _SuperResolutionScreenState();
}

class _SuperResolutionScreenState extends State<SuperResolutionScreen> with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  File? _inputFile;
  File? _enhancedFile;
  bool _isProcessing = false;
  bool _isShowingEnhanced = false;
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  MediaType _mediaType = MediaType.image;

  // Only keep enhancement scale
  int _enhancementScale = 2;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Request permissions when the app starts
    _requestPermissions();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    // Request permissions for camera and storage
    await [
      Permission.camera,
      Permission.storage,
      Permission.photos,
    ].request();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(source: source);

      if (file != null) {
        setState(() {
          _inputFile = File(file.path);
          _enhancedFile = null;
          _isShowingEnhanced = false;
          _mediaType = MediaType.image;
        });
      }
    } catch (e) {
      _showError('Error selecting image: ${e.toString()}');
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      // Check permissions first
      if (source == ImageSource.camera) {
        final cameraStatus = await Permission.camera.status;
        if (!cameraStatus.isGranted) {
          await Permission.camera.request();
          if (!await Permission.camera.isGranted) {
            _showError('Camera permission denied');
            return;
          }
        }
      } else {
        final storageStatus = await Permission.photos.status;
        if (!storageStatus.isGranted) {
          await Permission.photos.request();
          if (!await Permission.photos.isGranted) {
            _showError('Gallery access denied');
            return;
          }
        }
      }

      final XFile? file = await _picker.pickVideo(source: source);

      if (file != null) {
        // Dispose old controller if it exists
        await _videoController?.dispose();
        setState(() {
          _isVideoInitialized = false;
          _enhancedFile = null;
          _isShowingEnhanced = false;
        });

        try {
          // Initialize new controller
          final controller = VideoPlayerController.file(File(file.path));
          await controller.initialize();

          setState(() {
            _inputFile = File(file.path);
            _mediaType = MediaType.video;
            _videoController = controller;
            _isVideoInitialized = true;
          });

          // Start video but immediately pause it (to display first frame)
          await controller.play();
          await controller.pause();

        } catch (e) {
          _showError('Error initializing video: ${e.toString()}');
        }
      }
    } catch (e) {
      _showError('Error selecting video: ${e.toString()}');
    }
  }

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select Media Type',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                // Media type selection
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildMediaTypeOption(
                      icon: Icons.image,
                      label: 'Image',
                      onTap: () {
                        Navigator.pop(context);
                        _showImageSourcePicker(MediaType.image);
                      },
                    ),
                    _buildMediaTypeOption(
                      icon: Icons.videocam,
                      label: 'Video',
                      onTap: () {
                        Navigator.pop(context);
                        _showImageSourcePicker(MediaType.video);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showImageSourcePicker(MediaType mediaType) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select ${mediaType == MediaType.image ? 'Image' : 'Video'} Source',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildImageSourceOption(
                      icon: Icons.photo_library,
                      label: 'Gallery',
                      onTap: () {
                        Navigator.pop(context);
                        mediaType == MediaType.image
                            ? _pickImage(ImageSource.gallery)
                            : _pickVideo(ImageSource.gallery);
                      },
                    ),
                    _buildImageSourceOption(
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      onTap: () {
                        Navigator.pop(context);
                        mediaType == MediaType.image
                            ? _pickImage(ImageSource.camera)
                            : _pickVideo(ImageSource.camera);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMediaTypeOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 30,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 30,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Future<void> _startProcessing() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final modelManager = Provider.of<ModelManager>(context, listen: false);

      // Get the model type from preferences
      final modelType = await modelManager.getModelForEnhancement(
        isVideo: _mediaType == MediaType.video,
        scale: _enhancementScale,
      );

      if (modelType == null) {
        throw Exception('No model available for ${_enhancementScale}x enhancement. Please download a model from Settings.');
      }

      // Show which model is being used
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Enhancing with ${modelType.displayName} ${_enhancementScale}x model',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // For demonstration, we'll animate a progress bar
      _animationController.reset();
      _animationController.forward();

      // Process the image
      if (_mediaType == MediaType.image) {
        final enhancedFile = await SuperResolutionProcessor.enhanceImage(
          inputFile: _inputFile!,
          modelType: modelType,
          scale: _enhancementScale,
        );

        if (mounted) {
          setState(() {
            _enhancedFile = enhancedFile;
            _isShowingEnhanced = enhancedFile != null;
            _isProcessing = false;
          });
        }
      } else {
        // For video, in this version we'll just simulate the enhancement
        await Future.delayed(const Duration(seconds: 3));

        if (mounted) {
          setState(() {
            _isProcessing = false;
          });

          // Show success dialog for video
          _showSuccessDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        if (e.toString().contains('No model available')) {
          _showModelMissingDialog();
        } else {
          _showError(e.toString());
        }
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Success!'),
          ],
        ),
        content: Text(
          'Your ${_mediaType == MediaType.image ? 'image' : 'video'} has been enhanced by ${_enhancementScale}x. '
              '${_mediaType == MediaType.video ? 'Video enhancement is simulated in this version.' : ''}',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showModelMissingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Model Required'),
        content: const Text(
            'You need to download a model before enhancing media. '
                'Would you like to go to Settings to download a model now?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('LATER'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            child: const Text('GO TO SETTINGS'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _toggleBeforeAfter() {
    if (_enhancedFile != null) {
      setState(() {
        _isShowingEnhanced = !_isShowingEnhanced;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Super Resolution',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      Theme.of(context).colorScheme.primary.withOpacity(0.05),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              // Settings button
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                },
              ),
              // Info button
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () {
                  // Show info dialog
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('About Super Resolution'),
                      content: const Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'This app uses AI to enhance image and video quality. Select media to upscale its resolution and improve details.',
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Security & Privacy',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '• Your data is processed locally on your device\n'
                                '• We do not save any of your data\n'
                                '• All processing is done securely on-device',
                          ),
                        ],
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
            ],
          ),
          SliverToBoxAdapter(
            child: _buildContent(),
          ),
        ],
      ),
      floatingActionButton: _inputFile != null && !_isProcessing
          ? FloatingActionButton.extended(
        onPressed: _startProcessing,
        icon: const Icon(Icons.auto_fix_high),
        label: const Text('Enhance'),
      )
          : null,
    );
  }

  Widget _buildContent() {
    if (_inputFile == null) {
      return _buildEmptyState();
    }

    return _mediaType == MediaType.image
        ? _buildImagePreview()
        : _buildVideoPreview();
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Image.asset(
            'assets/placeholder_image.png',
            height: 180,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 180,
                width: 180,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.image_outlined,
                  size: 80,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              );
            },
          ),
          const SizedBox(height: 40),
          const Text(
            'Enhance your media',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Transform low-resolution images and videos into crisp, detailed content',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: _showMediaPicker,
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('Select Media'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(height: 40),
          _buildFeatureList(),
        ],
      ),
    );
  }

  Widget _buildFeatureList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 12, bottom: 12),
          child: Text(
            'Features:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        _buildFeatureItem(
          icon: Icons.hd,
          title: 'Up to 4x Resolution',
          description: 'Make your media larger without losing quality',
        ),
        _buildFeatureItem(
          icon: Icons.auto_awesome,
          title: 'Enhance Details',
          description: 'Sharpen and bring out hidden details in your photos and videos',
        ),
        _buildFeatureItem(
          icon: Icons.healing,
          title: 'Reduce Noise',
          description: 'Clean up noise and artifacts in low-quality media',
        ),
        _buildFeatureItem(
          icon: Icons.security,
          title: 'Secure Processing',
          description: 'All processing happens locally on your device',
        ),
      ],
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 28,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    AspectRatio(
                      aspectRatio: 4/3,
                      child: _enhancedFile != null && _isShowingEnhanced
                          ? Image.file(
                        _enhancedFile!,
                        fit: BoxFit.cover,
                      )
                          : Image.file(
                        _inputFile!,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (!_isProcessing) ...[
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: Row(
                          children: [
                            if (_enhancedFile != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: IconButton(
                                  onPressed: _toggleBeforeAfter,
                                  icon: Icon(_isShowingEnhanced
                                      ? Icons.visibility_outlined
                                      : Icons.visibility),
                                  tooltip: _isShowingEnhanced ? 'Show Original' : 'Show Enhanced',
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            IconButton(
                              onPressed: _showMediaPicker,
                              icon: const Icon(Icons.edit),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_enhancedFile != null)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _isShowingEnhanced ? Colors.green : Colors.grey.shade700,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _isShowingEnhanced ? 'Enhanced' : 'Original',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (_isProcessing)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Enhancing Image...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        AnimatedBuilder(
                          animation: _progressAnimation,
                          builder: (context, child) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LinearProgressIndicator(
                                  value: _progressAnimation.value,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Progress: ${(_progressAnimation.value * 100).toInt()}%',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  )
              ],
            ),
          ),

          if (!_isProcessing) ...[
            const SizedBox(height: 24),
            _buildScaleSelector(),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: _isVideoInitialized && _videoController != null
                          ? _videoController!.value.aspectRatio
                          : 16/9,
                      child: _isVideoInitialized && _videoController != null
                          ? VideoPlayer(_videoController!)
                          : Container(
                        color: Colors.black,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    if (_isVideoInitialized && _videoController != null && !_isProcessing)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _videoController!.value.isPlaying
                                ? _videoController!.pause()
                                : _videoController!.play();
                          });
                        },
                        child: CircleAvatar(
                          backgroundColor: Colors.black45,
                          radius: 30,
                          child: Icon(
                            _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                            size: 30,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    if (!_isProcessing)
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: IconButton(
                          onPressed: _showMediaPicker,
                          icon: const Icon(Icons.edit),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                if (_isProcessing)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Enhancing Video...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        AnimatedBuilder(
                          animation: _progressAnimation,
                          builder: (context, child) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LinearProgressIndicator(
                                  value: _progressAnimation.value,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Progress: ${(_progressAnimation.value * 100).toInt()}%',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                if (_isVideoInitialized && _videoController != null && !_isProcessing)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Duration: ${_formatDuration(_videoController!.value.duration)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        FutureBuilder<int>(
                          future: _inputFile?.length(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              final fileSizeMB = (snapshot.data! / (1024 * 1024)).toStringAsFixed(2);
                              return Text(
                                'Size: $fileSizeMB MB',
                                style: const TextStyle(fontSize: 14),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          if (!_isProcessing) ...[
            const SizedBox(height: 24),
            _buildScaleSelector(),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  Widget _buildScaleSelector() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upscaling Factor',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildScaleOption(2),
                _buildScaleOption(3),
                _buildScaleOption(4),
              ],
            ),

            const SizedBox(height: 16),
            Consumer<ModelManager>(
              builder: (context, modelManager, _) {
                final availableText = modelManager.downloadedModelTypes.isNotEmpty
                    ? 'Using downloaded models from Settings'
                    : 'No models available. Visit Settings to download';

                return Text(
                  availableText,
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: modelManager.downloadedModelTypes.isNotEmpty
                        ? Colors.grey.shade600
                        : Colors.red.shade600,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScaleOption(int scale) {
    final isSelected = _enhancementScale == scale;

    return Consumer<ModelManager>(
        builder: (context, modelManager, _) {
          final hasModel = scale == 2 && (modelManager.imageModelX2 != null || modelManager.videoModelX2 != null) ||
              scale == 3 && (modelManager.imageModelX3 != null || modelManager.videoModelX3 != null) ||
              scale == 4 && (modelManager.imageModelX4 != null || modelManager.videoModelX4 != null);

          return GestureDetector(
            onTap: () {
              setState(() {
                _enhancementScale = scale;
              });
            },
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${scale}x',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Text(
                          'Scale',
                          style: TextStyle(
                            fontSize: 14,
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasModel)
                    Positioned(
                      top: 5,
                      right: 5,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }
    );
  }
}