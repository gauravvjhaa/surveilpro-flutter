import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model_manager.dart';
import '../model_types.dart';

class ModelSelectionScreen extends StatefulWidget {
  final bool isVideo;
  final int scale;

  const ModelSelectionScreen({
    Key? key,
    required this.isVideo,
    required this.scale,
  }) : super(key: key);

  @override
  State<ModelSelectionScreen> createState() => _ModelSelectionScreenState();
}

class _ModelSelectionScreenState extends State<ModelSelectionScreen> {
  ModelType? _selectedModel;

  @override
  void initState() {
    super.initState();

    // Initialize selected model based on current preferences
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final modelManager = Provider.of<ModelManager>(context, listen: false);
      final currentModel = widget.isVideo
          ? (widget.scale == 2
          ? modelManager.videoModelX2
          : widget.scale == 3
          ? modelManager.videoModelX3
          : modelManager.videoModelX4)
          : (widget.scale == 2
          ? modelManager.imageModelX2
          : widget.scale == 3
          ? modelManager.imageModelX3
          : modelManager.imageModelX4);

      setState(() {
        _selectedModel = currentModel;
      });
    });
  }

  void _updateSelectedModel(ModelType? model) {
    final modelManager = Provider.of<ModelManager>(context, listen: false);

    setState(() {
      _selectedModel = model;
    });

    // Update the model manager
    modelManager.updateModelPreference(
      isVideo: widget.isVideo,
      scale: widget.scale,
      model: model,
    ).then((_) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${model?.readableName ?? "None"} selected as default'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select ${widget.scale}× ${widget.isVideo ? "Video" : "Image"} Model'),
      ),
      body: Consumer<ModelManager>(
        builder: (context, modelManager, _) {
          // Filter models by scale and type
          final availableModels = ModelType.values
              .where((m) => m.scale == widget.scale)
              .where((m) => {
            // Filter models to match image/video context
            if (widget.isVideo) {
              ModelType.surveilProX2,
              ModelType.surveilProX3,
              ModelType.surveilProX4,
            } else {
              ModelType.realEsrganX2,
              ModelType.realEsrganX3,
              ModelType.realEsrganX4,
            }
          }.contains(m))
              .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Choose which model to use for ${widget.scale}× upscaling',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  itemCount: availableModels.length + 1, // +1 for "None" option
                  itemBuilder: (context, index) {
                    // Special case for "None" option
                    if (index == 0) {
                      return _buildModelCard(
                        null,
                        modelManager,
                        isSelected: _selectedModel == null,
                      );
                    }

                    final modelType = availableModels[index - 1];
                    return _buildModelCard(
                      modelType,
                      modelManager,
                      isSelected: modelType == _selectedModel,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModelCard(ModelType? modelType, ModelManager modelManager, {required bool isSelected}) {
    // The None option
    if (modelType == null) {
      return Card(
        elevation: isSelected ? 4 : 1,
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isSelected
              ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: () => _updateSelectedModel(null),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.close,
                      size: 30,
                      color: Colors.grey,
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Model information
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "None (Use Basic Upscaling)",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Standard algorithm without AI enhancement",
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),

                Radio<ModelType?>(
                  value: null,
                  groupValue: _selectedModel,
                  onChanged: (value) => _updateSelectedModel(value),
                )
              ],
            ),
          ),
        ),
      );
    }

    // Regular model options
    final modelInfo = modelManager.allModels.firstWhere((info) => info.type == modelType);

    final isDownloaded = modelInfo.isDownloaded;
    final isDownloading = modelInfo.isDownloading;
    final downloadProgress = modelInfo.downloadProgress ?? 0.0;

    return Card(
      elevation: isSelected ? 4 : 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          if (isDownloaded) {
            _updateSelectedModel(modelType);
          } else if (!isDownloading) {
            _showDownloadDialog(modelType, modelManager);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: modelType.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    modelType.icon,
                    size: 30,
                    color: modelType.color,
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Model information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      modelType.readableName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      modelType.description,
                      style: const TextStyle(fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${modelType.sizeInMB.toStringAsFixed(1)} MB',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // Download status or selection indicator
              if (isDownloaded)
                Radio<ModelType?>(
                  value: modelType,
                  groupValue: _selectedModel,
                  onChanged: (value) => _updateSelectedModel(value),
                )
              else if (isDownloading)
                SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    value: downloadProgress,
                    strokeWidth: 3,
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () => _showDownloadDialog(modelType, modelManager),
                  tooltip: 'Download model',
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDownloadDialog(ModelType modelType, ModelManager modelManager) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Download ${modelType.readableName}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will download a ${modelType.sizeInMB.toStringAsFixed(1)} MB model.'),
            const SizedBox(height: 16),
            const Text('Model will be stored on your device for offline use.'),
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
              _downloadModel(modelType, modelManager);
            },
            child: const Text('DOWNLOAD'),
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

      // Auto-select the model after download
      _updateSelectedModel(modelType);
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
}