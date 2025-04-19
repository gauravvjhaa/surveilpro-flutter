import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model_manager.dart';
import '../model_types.dart';

class ModelsScreen extends StatefulWidget {
  const ModelsScreen({Key? key}) : super(key: key);

  @override
  State<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends State<ModelsScreen> with SingleTickerProviderStateMixin {
  bool _showImageModels = true; // Toggle between image and video models
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _showImageModels = _tabController.index == 0;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Models'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.image),
              text: 'Image Models',
            ),
            Tab(
              icon: Icon(Icons.videocam),
              text: 'Video Models',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.storage),
            onPressed: () => _showStorageInfo(context),
            tooltip: 'Storage Info',
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () => _showModelDebugInfo(
                Provider.of<ModelManager>(context, listen: false)
            ),
            tooltip: 'Debug Info',
          ),
        ],
      ),
      body: Consumer<ModelManager>(
        builder: (context, modelManager, _) {
          if (!modelManager.isInitialized) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (modelManager.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error initializing models',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(modelManager.errorMessage!),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      modelManager.initialize();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              // Image models tab
              _buildModelsTab(modelManager, isVideo: false),

              // Video models tab
              _buildModelsTab(modelManager, isVideo: true),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildBottomInfoBar(),
    );
  }

  Widget _buildModelsTab(ModelManager modelManager, {required bool isVideo}) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSelectedModelSection(modelManager, scale: 2, isVideo: isVideo),
        _buildSelectedModelSection(modelManager, scale: 3, isVideo: isVideo),
        _buildSelectedModelSection(modelManager, scale: 4, isVideo: isVideo),

        const SizedBox(height: 24),
        const Divider(),

        // Downloaded models section
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            'Downloaded Models',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),

        ...modelManager.allModels
            .where((info) => info.isDownloaded)
            .map((info) => _buildDownloadedModelItem(info, modelManager))
            .toList(),

        if (modelManager.allModels.where((info) => info.isDownloaded).isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32.0),
            child: Column(
              children: [
                Icon(
                  Icons.no_photography,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No models downloaded yet',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

        const Divider(),

        // Available models section
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            'Available Models',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),

        ...ModelHelper.getModelsByFamily().entries.map(
              (entry) => _buildModelFamilySection(entry.key, entry.value, modelManager),
        ),
      ],
    );
  }

  // Add this method to the ModelsScreen class
  void _showModelDebugInfo(ModelManager modelManager) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Model Debug Info'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Image Model X2: ${modelManager.imageModelX2?.readableName ?? "None"}'),
              Text('Image Model X3: ${modelManager.imageModelX3?.readableName ?? "None"}'),
              Text('Image Model X4: ${modelManager.imageModelX4?.readableName ?? "None"}'),
              Text('Video Model X2: ${modelManager.videoModelX2?.readableName ?? "None"}'),
              Text('Video Model X3: ${modelManager.videoModelX3?.readableName ?? "None"}'),
              Text('Video Model X4: ${modelManager.videoModelX4?.readableName ?? "None"}'),
              const Divider(),
              const Text('Downloaded Models:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...modelManager.allModels
                  .where((info) => info.isDownloaded)
                  .map((info) => Text('• ${info.type.readableName}'))
                  .toList(),
              if (modelManager.allModels.where((info) => info.isDownloaded).isEmpty)
                const Text('No models downloaded'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomInfoBar() {
    return Consumer<ModelManager>(
      builder: (context, modelManager, _) {
        return FutureBuilder<Map<String, dynamic>>(
          future: modelManager.getStorageStats(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox.shrink();
            }

            final stats = snapshot.data!;

            return Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).cardColor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.sd_storage, size: 20),
                      const SizedBox(width: 8),
                      Text('Used: ${stats['used']} MB'),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.storage, size: 20),
                      const SizedBox(width: 8),
                      Text('Free: ${stats['free']} GB'),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Replace the _buildSelectedModelSection method with this updated version:

  Widget _buildSelectedModelSection(
      ModelManager modelManager,
      {required int scale, required bool isVideo}
      ) {
    final ModelType? selectedModel = isVideo
        ? (scale == 2
        ? modelManager.videoModelX2
        : scale == 3
        ? modelManager.videoModelX3
        : modelManager.videoModelX4)
        : (scale == 2
        ? modelManager.imageModelX2
        : scale == 3
        ? modelManager.imageModelX3
        : modelManager.imageModelX4);

    // Get ALL models with this scale, not just filtered by type
    final availableModels = ModelType.values
        .where((model) => model.scale == scale)
        .toList();

    // Get downloaded models of this scale
    final downloadedModels = availableModels
        .where((model) => modelManager.allModels
        .any((info) => info.type == model && info.isDownloaded))
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${scale}×',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${scale}× Upscaling',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (selectedModel != null) ...[
              _buildActiveModelPreview(selectedModel),
            ] else ...[
              const Text(
                'No model selected for this scale',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ],

            const SizedBox(height: 16),

            DropdownButtonFormField<ModelType?>(
              decoration: const InputDecoration(
                labelText: 'Select Model',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              value: selectedModel,
              isExpanded: true,
              hint: const Text('Select a model'),
              onChanged: (newValue) {
                modelManager.updateModelPreference(
                  isVideo: isVideo,
                  scale: scale,
                  model: newValue,
                );
              },
              items: [
                const DropdownMenuItem<ModelType?>(
                  value: null,
                  child: Text('None (Basic upscaling)'),
                ),
                ...downloadedModels.map((model) => DropdownMenuItem<ModelType>(
                  value: model,
                  child: Text(model.readableName),
                )).toList(),
              ],
            ),

            if (downloadedModels.isEmpty) ...[
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Download Models'),
                  onPressed: () {
                    // Scroll down to available models section
                    // In a real app you'd use a ScrollController
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActiveModelPreview(ModelType model) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: model.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: model.color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: model.color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              model.icon,
              color: model.color,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.readableName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  model.description,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadedModelItem(ModelInfo info, ModelManager modelManager) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: info.type.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  info.type.icon,
                  color: info.type.color,
                  size: 24,
                ),
              ),
            ),
            CircleAvatar(
              radius: 10,
              backgroundColor: Colors.white,
              child: Text(
                '${info.type.scale}×',
                style: TextStyle(
                  fontSize: 10,
                  color: info.type.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        title: Text(info.type.readableName),
        subtitle: Text('${info.type.sizeInMB.toStringAsFixed(1)} MB'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _confirmDeleteModel(info.type, modelManager),
          tooltip: 'Delete model',
          color: Colors.red.shade300,
        ),
      ),
    );
  }

  Widget _buildModelFamilySection(
      String familyName,
      List<ModelType> models,
      ModelManager modelManager
      ) {
    // Sort models by scale
    final sortedModels = [...models]..sort((a, b) => a.scale.compareTo(b.scale));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: sortedModels.first.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  sortedModels.first.icon,
                  size: 16,
                  color: sortedModels.first.color,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                familyName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        ...sortedModels.map((model) => _buildAvailableModelItem(model, modelManager)).toList(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAvailableModelItem(ModelType modelType, ModelManager modelManager) {
    final modelInfo = modelManager.allModels.firstWhere(
          (info) => info.type == modelType,
    );

    final isDownloaded = modelInfo.isDownloaded;
    final isDownloading = modelInfo.isDownloading;
    final progress = modelInfo.downloadProgress ?? 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: modelType.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${modelType.scale}×',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: modelType.color,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    modelType.readableName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${modelType.sizeInMB.toStringAsFixed(1)} MB',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isDownloaded)
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => _confirmDeleteModel(modelType, modelManager),
                    color: Colors.red.shade300,
                  ),
                ],
              )
            else if (isDownloading)
              SizedBox(
                width: 80,
                child: Column(
                  children: [
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 4),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              ElevatedButton.icon(
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Get'),
                onPressed: () => _downloadModel(modelType, modelManager),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  minimumSize: const Size(80, 36),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteModel(ModelType modelType, ModelManager modelManager) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${modelType.readableName}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this model? This will free up ${modelType.sizeInMB.toStringAsFixed(1)} MB of storage.',
            ),
            const SizedBox(height: 12),
            const Text(
              'You can download it again later if needed.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteModel(modelType, modelManager);
            },
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.red,
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadModel(ModelType modelType, ModelManager modelManager) async {
    final result = await modelManager.downloadModel(modelType);

    if (result && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${modelType.readableName} downloaded successfully'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to download model'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteModel(ModelType modelType, ModelManager modelManager) async {
    final result = await modelManager.deleteModel(modelType);

    if (result && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${modelType.readableName} deleted successfully'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to delete model'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showStorageInfo(BuildContext context) async {
    final modelManager = Provider.of<ModelManager>(context, listen: false);
    final stats = await modelManager.getStorageStats();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Storage Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.sd_storage,
                color: Theme.of(context).primaryColor,
              ),
              title: const Text('Models Storage'),
              subtitle: Text('${stats['used']} MB used'),
            ),
            const Divider(),
            ListTile(
              leading: Icon(
                Icons.storage,
                color: Theme.of(context).primaryColor,
              ),
              title: const Text('Free Space'),
              subtitle: Text('${stats['free']} GB available'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Models are stored on your device and only need to be downloaded once.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }
}