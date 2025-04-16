import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'model_types.dart';
import 'model_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modelManager = Provider.of<ModelManager>(context);

    if (!modelManager.isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Preferences'),
            Tab(text: 'Model Zoo'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPreferencesTab(),
          _buildModelZooTab(),
        ],
      ),
    );
  }

  Widget _buildPreferencesTab() {
    final modelManager = Provider.of<ModelManager>(context);
    final downloadedModels = modelManager.downloadedModelTypes;
    final hasDownloadedModels = downloadedModels.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Error message if any
        if (modelManager.errorMessage != null)
          Card(
            color: Colors.red.shade100,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                modelManager.errorMessage!,
                style: TextStyle(color: Colors.red.shade900),
              ),
            ),
          ),

        // No models warning if needed
        if (!hasDownloadedModels)
          Card(
            color: Colors.orange.shade100,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.orange.shade800),
                      const SizedBox(width: 8),
                      Text(
                        'No Models Available',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please download at least one model from the Model Zoo tab '
                        'before configuring preferences.',
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      _tabController.animateTo(1); // Switch to Model Zoo tab
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Go to Model Zoo'),
                  ),
                ],
              ),
            ),
          ),

        // Models Section
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Enhancement Models',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),

                // Image Models Section
                const Text(
                  'Image Enhancement Models',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),

                // Image x2 Model
                _buildModelSelector(
                  label: 'Image 2x Upscaling',
                  value: modelManager.imageModelX2,
                  availableModels: downloadedModels,
                  isVideo: false,
                  scale: 2,
                  onChanged: hasDownloadedModels ? (_) {} : null,
                ),

                const SizedBox(height: 16),

                // Image x3 Model
                _buildModelSelector(
                  label: 'Image 3x Upscaling',
                  value: modelManager.imageModelX3,
                  availableModels: downloadedModels,
                  isVideo: false,
                  scale: 3,
                  onChanged: hasDownloadedModels ? (_) {} : null,
                ),

                const SizedBox(height: 16),

                // Image x4 Model
                _buildModelSelector(
                  label: 'Image 4x Upscaling',
                  value: modelManager.imageModelX4,
                  availableModels: downloadedModels,
                  isVideo: false,
                  scale: 4,
                  onChanged: hasDownloadedModels ? (_) {} : null,
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),

                // Video Models Section
                const Text(
                  'Video Enhancement Models',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),

                // Video x2 Model
                _buildModelSelector(
                  label: 'Video 2x Upscaling',
                  value: modelManager.videoModelX2,
                  availableModels: downloadedModels,
                  isVideo: true,
                  scale: 2,
                  onChanged: hasDownloadedModels ? (_) {} : null,
                ),

                const SizedBox(height: 16),

                // Video x3 Model
                _buildModelSelector(
                  label: 'Video 3x Upscaling',
                  value: modelManager.videoModelX3,
                  availableModels: downloadedModels,
                  isVideo: true,
                  scale: 3,
                  onChanged: hasDownloadedModels ? (_) {} : null,
                ),

                const SizedBox(height: 16),

                // Video x4 Model
                _buildModelSelector(
                  label: 'Video 4x Upscaling',
                  value: modelManager.videoModelX4,
                  availableModels: downloadedModels,
                  isVideo: true,
                  scale: 4,
                  onChanged: hasDownloadedModels ? (_) {} : null,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Note that changes are applied immediately
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Changes to preferences are saved automatically.',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModelZooTab() {
    return Consumer<ModelManager>(
        builder: (context, modelManager, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Introduction card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.catching_pokemon,
                            color: Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'AI Model Zoo',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Download AI models to enhance your images and videos. '
                            'Models are processed locally on your device for privacy and speed.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Storage info
              FutureBuilder(
                  future: modelManager.getStorageStats(),
                  builder: (context, snapshot) {
                    String storageInfo = "Calculating storage usage...";

                    if (snapshot.hasData) {
                      final data = snapshot.data as Map<String, dynamic>;
                      storageInfo = "Models storage: ${data['used']} MB used / ${data['free']} GB free";
                    }

                    return Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.storage, size: 16, color: Colors.grey.shade700),
                          const SizedBox(width: 8),
                          Text(
                            storageInfo,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    );
                  }
              ),

              // Models grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: modelManager.allModels.length,
                itemBuilder: (context, index) {
                  final model = modelManager.allModels[index];
                  return _buildModelCard(model, modelManager);
                },
              ),
            ],
          );
        }
    );
  }

  Widget _buildModelCard(ModelInfo model, ModelManager modelManager) {
    final isDownloading = model.isDownloading;
    final isDownloaded = model.isDownloaded;
    final progress = model.downloadProgress;

    // Check if this model is selected in any preference
    final isUsedInSettings =
        modelManager.imageModelX2 == model.type ||
            modelManager.imageModelX3 == model.type ||
            modelManager.imageModelX4 == model.type ||
            modelManager.videoModelX2 == model.type ||
            modelManager.videoModelX3 == model.type ||
            modelManager.videoModelX4 == model.type;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: isDownloaded ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isDownloaded
            ? BorderSide(color: isUsedInSettings ? Colors.blue.shade400 : Colors.green.shade400, width: 2)
            : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Model header with colored background
          Container(
            color: isDownloaded
                ? (isUsedInSettings ? Colors.blue.shade50 : Colors.green.shade50)
                : Colors.grey.shade100,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: isDownloaded
                      ? (isUsedInSettings ? Colors.blue.shade400 : Colors.green.shade400)
                      : Theme.of(context).colorScheme.primary.withOpacity(0.7),
                  radius: 16,
                  child: Icon(
                    isDownloaded
                        ? (isUsedInSettings ? Icons.star : Icons.check)
                        : Icons.auto_awesome,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    model.type.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Model size
                  Row(
                    children: [
                      Icon(Icons.sd_card, size: 14, color: Colors.grey.shade700),
                      const SizedBox(width: 4),
                      Text(
                        '${model.type.sizeMB} MB',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Model description
                  Text(
                    model.type.description,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const Spacer(),

                  // Usage label if applicable
                  if (isUsedInSettings && isDownloaded)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Currently in use',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  // Status indicator or progress bar
                  if (isDownloading && progress != null) ...[
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey.shade200,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Downloading: ${(progress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ] else if (isDownloaded) ...[
                    OutlinedButton.icon(
                      onPressed: () => _confirmDeleteModel(context, model.type, modelManager),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        minimumSize: const Size.fromHeight(32),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ] else ...[
                    ElevatedButton.icon(
                      onPressed: () async {
                        final success = await modelManager.downloadModel(model.type);
                        if (mounted && success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${model.type.displayName} downloaded successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Download'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(32),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteModel(BuildContext context, ModelType modelType, ModelManager modelManager) async {
    final isUsedInSettings =
        modelManager.imageModelX2 == modelType ||
            modelManager.imageModelX3 == modelType ||
            modelManager.imageModelX4 == modelType ||
            modelManager.videoModelX2 == modelType ||
            modelManager.videoModelX3 == modelType ||
            modelManager.videoModelX4 == modelType;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isUsedInSettings ? 'Model In Use' : 'Delete Model?'),
        content: Text(
            isUsedInSettings
                ? '${modelType.displayName} is currently selected for use. '
                'Deleting it will reset any settings using this model.\n\n'
                'Are you sure you want to delete it?'
                : 'Are you sure you want to delete ${modelType.displayName}? '
                'You can download it again later if needed.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      final success = await modelManager.deleteModel(modelType);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${modelType.displayName} deleted successfully'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete ${modelType.displayName}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildModelSelector({
    required String label,
    required ModelType? value,
    required List<ModelType> availableModels,
    required bool isVideo,
    required int scale,
    ValueChanged<ModelType?>? onChanged,
  }) {
    final modelManager = Provider.of<ModelManager>(context, listen: false);

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(label),
        ),
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: onChanged == null
                    ? Colors.grey.shade300
                    : Theme.of(context).primaryColor.withOpacity(0.5),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ModelType>(
                value: value,
                isExpanded: true,
                onChanged: onChanged == null ? null : (newValue) {
                  // Update the model preference immediately
                  modelManager.updateModelPreference(
                      isVideo: isVideo,
                      scale: scale,
                      model: newValue
                  );

                  // Show feedback
                  if (newValue != null && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${newValue.displayName} selected for $scale× ${isVideo ? 'video' : 'image'} enhancement'),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                hint: Text(
                  onChanged == null
                      ? 'No models available'
                      : 'Select a model',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                items: availableModels.map((ModelType type) {
                  return DropdownMenuItem<ModelType>(
                    value: type,
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 14,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            type.displayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}