import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:path/path.dart' as path;
import '../utils/multipart_parser.dart';
import '../utils/html_generator.dart';

/// Service for managing the HTTP file server
class HttpServerService {
  HttpServer? _server;
  final Directory sharedDirectory;
  final List<String> whitelistedIPs;
  final List<FileSystemEntity> Function() getFiles;

  HttpServerService({
    required this.sharedDirectory,
    required this.whitelistedIPs,
    required this.getFiles,
  });

  bool get isRunning => _server != null;

  /// Start the HTTP server
  Future<void> start(int port) async {
    if (_server != null) {
      throw Exception('Server is already running');
    }

    // Clean up any leftover temp files from interrupted uploads
    await _cleanupTempFiles();

    final handler = const shelf.Pipeline()
        .addMiddleware(_ipWhitelistMiddleware)
        .addMiddleware(shelf.logRequests())
        .addHandler(_handleRequest);

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  }

  /// Clean up temporary upload files
  Future<void> _cleanupTempFiles() async {
    try {
      final tempDir = Directory(path.join(sharedDirectory.path, '.temp_uploads'));
      if (await tempDir.exists()) {
        await for (var entity in tempDir.list()) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  /// Stop the HTTP server
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  /// IP whitelist middleware
  shelf.Middleware get _ipWhitelistMiddleware {
    return (shelf.Handler handler) {
      return (shelf.Request request) async {
        // If whitelist is empty, allow all connections
        if (whitelistedIPs.isEmpty) {
          return handler(request);
        }

        final clientIP = request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
        final remoteIP = clientIP?.remoteAddress.address ?? '';

        // Check if IP is whitelisted
        if (whitelistedIPs.contains(remoteIP) || 
            remoteIP == '127.0.0.1' || 
            remoteIP == '::1') {
          return handler(request);
        }

        return shelf.Response.forbidden('Access denied: IP not whitelisted');
      };
    };
  }

  /// Handle incoming HTTP requests
  Future<shelf.Response> _handleRequest(shelf.Request request) async {
    final uri = request.url;

    // Main page with file listing and upload
    if (uri.path == '' || uri.path == '/') {
      return shelf.Response.ok(
        HtmlGenerator.generateMainPage(getFiles()),
        headers: {'Content-Type': 'text/html'},
      );
    }

    // Handle file upload
    if (uri.path == 'upload' && request.method == 'POST') {
      return await _handleFileUpload(request);
    }

    // Handle file download
    if (uri.path.startsWith('files/')) {
      final filename = uri.path.substring(6);
      return await _handleFileDownload(request, filename);
    }

    // Handle file list request (JSON)
    if (uri.path == 'api/files' && request.method == 'GET') {
      return _handleFileListRequest();
    }

    return shelf.Response.notFound('Not found');
  }

  /// Handle file upload with streaming to avoid memory bloat
  Future<shelf.Response> _handleFileUpload(shelf.Request request) async {
    try {
      final contentType = request.headers['content-type'] ?? '';
      
      if (!contentType.contains('multipart/form-data')) {
        return shelf.Response.badRequest(body: 'Invalid content type');
      }

      final boundary = contentType.split('boundary=').last;
      final boundaryBytes = utf8.encode('--$boundary');

      // Use streaming parser to avoid loading entire file into memory
      // This writes directly to disk as data arrives
      final parts = await MultipartParser.parseStream(
        request.read(),
        boundaryBytes,
        sharedDirectory.path,
      );
      
      if (parts.isEmpty) {
        return shelf.Response(
          400,
          body: jsonEncode({'success': false, 'message': 'No file found in request'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Return info about the first uploaded file
      final part = parts.first;
      final jsonResponse = jsonEncode({
        'success': true,
        'message': 'File uploaded successfully',
        'filename': part.filename,
        'size': part.size,
      });
      
      return shelf.Response.ok(
        jsonResponse,
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return shelf.Response(
        500,
        body: jsonEncode({'success': false, 'message': 'Upload failed: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Handle file download with streaming for large files and range request support
  Future<shelf.Response> _handleFileDownload(shelf.Request request, String filename) async {
    try {
      // URL decode the filename to handle special characters
      final decodedFilename = Uri.decodeComponent(filename);
      final file = File(path.join(sharedDirectory.path, decodedFilename));
      
      if (!await file.exists()) {
        return shelf.Response.notFound('File not found');
      }

      // Get file size for Content-Length header
      final fileSize = await file.length();

      // Always indicate that we support range requests
      final baseHeaders = {
        'Content-Type': 'application/octet-stream',
        'Content-Disposition': 'attachment; filename="$decodedFilename"',
        'Accept-Ranges': 'bytes',
      };

      // Check if this is a range request
      final rangeHeader = request.headers['range'];
      if (rangeHeader == null || !rangeHeader.startsWith('bytes=')) {
        // No range request - send the entire file
        return shelf.Response.ok(
          file.openRead(),
          headers: {
            ...baseHeaders,
            'Content-Length': fileSize.toString(),
          },
        );
      }

      // Parse the range request
      final rangeResult = _parseRangeHeader(rangeHeader, fileSize);
      if (rangeResult == null) {
        // Invalid range request
        return shelf.Response(
          416, // Range Not Satisfiable
          body: 'Invalid range request',
          headers: {
            'Content-Range': 'bytes */$fileSize',
          },
        );
      }

      final start = rangeResult['start'] as int;
      final end = rangeResult['end'] as int;
      final length = end - start + 1;

      // Stream only the requested portion of the file
      // This is crucial for multi-threaded downloads
      return shelf.Response(
        206, // Partial Content
        body: file.openRead(start, end + 1),
        headers: {
          ...baseHeaders,
          'Content-Length': length.toString(),
          'Content-Range': 'bytes $start-$end/$fileSize',
        },
      );
    } catch (e) {
      return shelf.Response.internalServerError(body: 'Download failed: $e');
    }
  }

  /// Parse the Range header and return start and end byte positions
  /// Returns null if the range is invalid
  Map<String, int>? _parseRangeHeader(String rangeHeader, int fileSize) {
    try {
      // Remove 'bytes=' prefix
      final range = rangeHeader.substring(6);
      
      // Handle multiple ranges by only supporting the first one
      final firstRange = range.split(',').first.trim();
      
      final parts = firstRange.split('-');
      if (parts.length != 2) {
        return null;
      }

      int start;
      int end;

      if (parts[0].isEmpty) {
        // Suffix range: -500 means last 500 bytes
        final suffixLength = int.tryParse(parts[1]);
        if (suffixLength == null || suffixLength <= 0) {
          return null;
        }
        start = fileSize - suffixLength;
        end = fileSize - 1;
        if (start < 0) {
          start = 0;
        }
      } else if (parts[1].isEmpty) {
        // Open-ended range: 500- means from byte 500 to end
        start = int.tryParse(parts[0]) ?? -1;
        if (start < 0) {
          return null;
        }
        end = fileSize - 1;
      } else {
        // Both start and end specified
        start = int.tryParse(parts[0]) ?? -1;
        end = int.tryParse(parts[1]) ?? -1;
        if (start < 0 || end < 0 || start > end) {
          return null;
        }
      }

      // Validate range
      if (start >= fileSize) {
        return null;
      }

      // Clamp end to file size
      if (end >= fileSize) {
        end = fileSize - 1;
      }

      return {'start': start, 'end': end};
    } catch (e) {
      return null;
    }
  }

  /// Handle file list request (returns JSON)
  shelf.Response _handleFileListRequest() {
    final files = getFiles();
    final fileList = files.map((file) {
      final filename = path.basename(file.path);
      final fileSize = (file as File).lengthSync();
      return {
        'filename': filename,
        'size': fileSize,
      };
    }).toList();

    return shelf.Response.ok(
      jsonEncode({'success': true, 'files': fileList}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

