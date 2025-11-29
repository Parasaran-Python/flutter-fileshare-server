import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import '../services/http_server_service.dart';

class ServerHomePage extends StatefulWidget {
  const ServerHomePage({super.key});

  @override
  State<ServerHomePage> createState() => _ServerHomePageState();
}

class _ServerHomePageState extends State<ServerHomePage> {
  HttpServerService? _serverService;
  bool _isRunning = false;
  int _port = 8080;
  String _serverUrl = '';
  final List<String> _whitelistedIPs = [];
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController(text: '8080');
  Directory? _sharedDirectory;
  final List<FileSystemEntity> _files = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initializeDirectory();
    // Auto-refresh file list every 3 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _loadFiles();
    });
  }

  Future<void> _initializeDirectory() async {
    try {
      Directory? directory;
      
      // Use app's data directory for reliable file access
      if (Platform.isAndroid) {
        // Use external storage directory (Android/data/package/)
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          directory = Directory(path.join(externalDir.path, 'shared_files'));
        }
      } else if (Platform.isIOS) {
        // iOS doesn't have external storage, use documents directory
        final docDir = await getApplicationDocumentsDirectory();
        directory = Directory(path.join(docDir.path, 'shared_files'));
      } else {
        // For desktop platforms, use a folder in user's documents
        final docDir = await getApplicationDocumentsDirectory();
        directory = Directory(path.join(docDir.parent.path, 'FlutterFileServer'));
      }
      
      if (directory == null) {
        _showError('Failed to get storage directory');
        return;
      }
      
      _sharedDirectory = directory;
      if (!await _sharedDirectory!.exists()) {
        await _sharedDirectory!.create(recursive: true);
      }
      
      // Initialize server service
      _serverService = HttpServerService(
        sharedDirectory: _sharedDirectory!,
        whitelistedIPs: _whitelistedIPs,
        getFiles: () => _files,
      );
      
      await _loadFiles();
    } catch (e) {
      _showError('Failed to initialize directory: $e');
    }
  }

  Future<void> _loadFiles() async {
    if (_sharedDirectory == null) return;
    try {
      final entities = await _sharedDirectory!.list().toList();
      setState(() {
        _files.clear();
        // Filter out files and exclude temp directory
        _files.addAll(entities.where((entity) {
          if (entity is! File) return false;
          // Exclude files in the temp uploads directory
          final relativePath = path.relative(entity.path, from: _sharedDirectory!.path);
          return !relativePath.startsWith('.temp_uploads');
        }).cast<File>());
      });
    } catch (e) {
      _showError('Failed to load files: $e');
    }
  }

  Future<void> _startServer() async {
    try {
      if (_serverService == null) {
        _showError('Server service not initialized');
        return;
      }

      _port = int.tryParse(_portController.text) ?? 8080;
      await _serverService!.start(_port);
      
      // Get local IP address
      final info = NetworkInfo();
      final wifiIP = await info.getWifiIP();
      
      setState(() {
        _isRunning = true;
        _serverUrl = 'http://${wifiIP ?? 'localhost'}:$_port';
      });

      // Enable wakelock to keep phone awake while server is running
      await WakelockPlus.enable();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server started at $_serverUrl')),
        );
      }
    } catch (e) {
      _showError('Failed to start server: $e');
    }
  }

  Future<void> _stopServer() async {
    if (_serverService != null) {
      await _serverService!.stop();
      
      // Disable wakelock when server stops
      await WakelockPlus.disable();
      
      setState(() {
        _isRunning = false;
        _serverUrl = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Server stopped')),
        );
      }
    }
  }

  void _addIPToWhitelist() {
    final ip = _ipController.text.trim();
    if (ip.isNotEmpty && !_whitelistedIPs.contains(ip)) {
      setState(() {
        _whitelistedIPs.add(ip);
        _ipController.clear();
      });
    }
  }

  void _removeIPFromWhitelist(String ip) {
    setState(() {
      _whitelistedIPs.remove(ip);
    });
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _copyPathToClipboard(String path) {
    Clipboard.setData(ClipboardData(text: path));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Path copied to clipboard!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openFolderInExternalApp() async {
    if (_sharedDirectory == null) {
      _showError('Shared directory not initialized');
      return;
    }

    try {
      final result = await OpenFile.open(_sharedDirectory!.path);
      
      if (mounted) {
        if (result.type == ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Opening folder...'),
              duration: Duration(seconds: 2),
            ),
          );
        } else if (result.type == ResultType.noAppToOpen) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No file manager app found to open the folder'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        } else if (result.type == ResultType.error) {
          _showError('Failed to open folder: ${result.message}');
        }
      }
    } catch (e) {
      _showError('Failed to open folder: $e');
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _ipController.dispose();
    _portController.dispose();
    _stopServer();
    // Ensure wakelock is disabled
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Share Server'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Server Status Card
            _buildServerStatusCard(),
            const SizedBox(height: 16),

            // Server Controls Card
            _buildServerControlsCard(),
            const SizedBox(height: 16),

            // IP Whitelist Card
            _buildIPWhitelistCard(),
            const SizedBox(height: 16),

            // Shared Files Card
            _buildSharedFilesCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildServerStatusCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isRunning ? Icons.check_circle : Icons.stop_circle,
                  color: _isRunning ? Colors.green : Colors.red,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  _isRunning ? 'Server Running' : 'Server Stopped',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Server URL:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (_isRunning)
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      _serverUrl,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: 'Copy URL',
                    onPressed: () => _copyPathToClipboard(_serverUrl),
                  ),
                ],
              )
            else
              const Text(
                'Start the server to get URL',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerControlsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Server Controls',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: 'Port',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.settings_ethernet),
              ),
              keyboardType: TextInputType.number,
              enabled: !_isRunning,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? null : _startServer,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Server'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? _stopServer : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Server'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIPWhitelistCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'IP Whitelist',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Leave empty to allow all connections',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ipController,
                    decoration: const InputDecoration(
                      labelText: 'IP Address',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.computer),
                      hintText: '192.168.1.100',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addIPToWhitelist,
                  icon: const Icon(Icons.add_circle),
                  color: Colors.green,
                  iconSize: 32,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_whitelistedIPs.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No IPs whitelisted - All connections allowed',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ),
              )
            else
              ...(_whitelistedIPs.map((ip) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.check_circle, color: Colors.green),
                      title: Text(ip),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeIPFromWhitelist(ip),
                      ),
                    ),
                  ))),
          ],
        ),
      ),
    );
  }

  Widget _buildSharedFilesCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Shared Files (${_files.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _pickAndCopyFiles,
                      icon: const Icon(Icons.add_circle),
                      color: Colors.blue,
                      tooltip: 'Import files',
                    ),
                    IconButton(
                      onPressed: _loadFiles,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_sharedDirectory != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Location: ${_sharedDirectory!.path}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.folder_open, size: 18),
                    tooltip: 'Open in file manager',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: _openFolderInExternalApp,
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: 'Copy path',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: () => _copyPathToClipboard(_sharedDirectory!.path),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _pickAndCopyFiles,
                icon: const Icon(Icons.upload_file),
                label: const Text('Import Files from Device'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_files.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No files available',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ),
              )
            else
              ...(_files.map((file) {
                final filename = path.basename(file.path);
                final fileSize = (file as File).lengthSync();
                final encodedFilename = Uri.encodeComponent(filename);
                final fileUrl = _isRunning ? '$_serverUrl/files/$encodedFilename' : '';
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.insert_drive_file),
                    title: Text(filename),
                    subtitle: Text(_formatBytes(fileSize)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isRunning)
                          IconButton(
                            icon: const Icon(Icons.link, size: 20),
                            tooltip: 'Copy URL',
                            onPressed: () {
                              _copyPathToClipboard(fileUrl);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('File URL copied to clipboard!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                          tooltip: 'Delete file',
                          onPressed: () => _confirmDeleteFile(filename),
                        ),
                      ],
                    ),
                  ),
                );
              })),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteFile(String filename) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Are you sure you want to delete "$filename"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteFile(filename);
    }
  }

  Future<void> _deleteFile(String filename) async {
    try {
      final file = File(path.join(_sharedDirectory!.path, filename));
      await file.delete();
      await _loadFiles();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File "$filename" deleted successfully')),
        );
      }
    } catch (e) {
      _showError('Failed to delete file: $e');
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) {
      return true; // iOS file picker handles permissions automatically
    }

    // Check Android version and request appropriate permissions
    if (await Permission.photos.isGranted || 
        await Permission.videos.isGranted || 
        await Permission.audio.isGranted ||
        await Permission.storage.isGranted) {
      return true;
    }

    // For Android 13+ (API 33+), request media permissions
    Map<Permission, PermissionStatus> statuses = {};
    
    if (Platform.isAndroid) {
      // Try to request the newer permissions (Android 13+)
      statuses = await [
        Permission.photos,
        Permission.videos,
        Permission.audio,
      ].request();
      
      // If any of the new permissions are granted, we're good
      if (statuses.values.any((status) => status.isGranted)) {
        return true;
      }
      
      // Fallback to storage permission for older Android versions
      final storageStatus = await Permission.storage.request();
      if (storageStatus.isGranted) {
        return true;
      }
    }

    return false;
  }

  Future<void> _pickAndCopyFiles() async {
    try {
      // Request storage permission first
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        if (mounted) {
          final openSettings = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Permission Required'),
              content: const Text(
                'Storage permission is required to pick files. Would you like to open app settings?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
          
          if (openSettings == true) {
            await openAppSettings();
          }
        }
        return;
      }

      // Pick files from device
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty) {
        return; // User cancelled
      }

      int successCount = 0;
      int failCount = 0;

      // Show progress indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Copying files...'),
              ],
            ),
            duration: Duration(hours: 1), // Long duration, we'll hide it manually
          ),
        );
      }

      // Copy each selected file to shared directory
      for (var file in result.files) {
        try {
          if (file.path == null) {
            failCount++;
            continue;
          }

          final sourceFile = File(file.path!);
          final fileName = path.basename(sourceFile.path);
          final destinationPath = path.join(_sharedDirectory!.path, fileName);
          
          // Check if file already exists
          final destFile = File(destinationPath);
          if (await destFile.exists()) {
            // Add timestamp to make filename unique
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final nameWithoutExt = path.basenameWithoutExtension(fileName);
            final ext = path.extension(fileName);
            final newFileName = '${nameWithoutExt}_$timestamp$ext';
            final newDestPath = path.join(_sharedDirectory!.path, newFileName);
            await sourceFile.copy(newDestPath);
          } else {
            await sourceFile.copy(destinationPath);
          }
          
          successCount++;
        } catch (e) {
          failCount++;
        }
      }

      // Hide progress indicator
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      // Refresh file list
      await _loadFiles();

      // Show result
      if (mounted) {
        String message;
        if (failCount == 0) {
          message = successCount == 1
              ? '1 file copied successfully'
              : '$successCount files copied successfully';
        } else {
          message = '$successCount succeeded, $failCount failed';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: failCount == 0 ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
      _showError('Failed to pick files: $e');
    }
  }
}

