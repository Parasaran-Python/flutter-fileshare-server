import 'dart:convert';
import 'dart:io';
import 'dart:async';

/// Helper class for multipart form data parsing
class MultipartPart {
  final String headers;
  final List<int> content;

  MultipartPart(this.headers, this.content);
}

/// Result of streaming multipart parse
class StreamedMultipartPart {
  final String headers;
  final String? filename;
  final File file;
  final int size;

  StreamedMultipartPart({
    required this.headers,
    required this.filename,
    required this.file,
    required this.size,
  });
}

/// Parser for multipart/form-data requests
class MultipartParser {
  /// Parse multipart form data with binary support (legacy method for small files)
  static List<MultipartPart> parse(List<int> bytes, List<int> boundary) {
    final parts = <MultipartPart>[];
    final crlfcrlf = [13, 10, 13, 10]; // \r\n\r\n separator between headers and content
    
    int position = 0;
    while (position < bytes.length) {
      // Find next boundary
      final boundaryIndex = _findBytes(bytes, boundary, position);
      if (boundaryIndex == -1) break;
      
      position = boundaryIndex + boundary.length;
      
      // Skip \r\n after boundary
      if (position + 1 < bytes.length && bytes[position] == 13 && bytes[position + 1] == 10) {
        position += 2;
      }
      
      // Find end of headers (double CRLF)
      final headersEnd = _findBytes(bytes, crlfcrlf, position);
      if (headersEnd == -1) break;
      
      // Extract headers as string
      final headerBytes = bytes.sublist(position, headersEnd);
      final headers = utf8.decode(headerBytes);
      
      // Content starts after headers
      final contentStart = headersEnd + 4;
      
      // Find next boundary to get content end
      final nextBoundary = _findBytes(bytes, boundary, contentStart);
      if (nextBoundary == -1) break;
      
      // Content ends before the \r\n that precedes the next boundary
      var contentEnd = nextBoundary - 2;
      if (contentEnd < contentStart) contentEnd = contentStart;
      
      // Extract content as binary
      final content = bytes.sublist(contentStart, contentEnd);
      
      parts.add(MultipartPart(headers, content));
      position = nextBoundary;
    }
    
    return parts;
  }

  /// Parse multipart form data using streaming for large files
  /// This method writes directly to disk without loading entire file into memory
  /// Files are first written to a temp directory and moved to final location on success
  static Future<List<StreamedMultipartPart>> parseStream(
    Stream<List<int>> stream,
    List<int> boundary,
    String outputDirectory,
  ) async {
    final parts = <StreamedMultipartPart>[];
    final crlfcrlf = [13, 10, 13, 10]; // \r\n\r\n
    
    // Create temp directory for in-progress uploads
    final tempDir = Directory('$outputDirectory/.temp_uploads');
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }
    
    final buffer = <int>[];
    
    // State machine variables
    bool inHeaders = false;
    bool inContent = false;
    String? currentHeaders;
    IOSink? currentFileSink;
    File? currentTempFile;
    String? targetFilename;
    int contentBytesWritten = 0;
    
    await for (var chunk in stream) {
      buffer.addAll(chunk);
      
      while (buffer.isNotEmpty) {
        if (!inHeaders && !inContent) {
          // Looking for boundary
          final boundaryIndex = _findBytesInBuffer(buffer, boundary, 0);
          if (boundaryIndex == -1) {
            // Keep last few bytes in case boundary is split across chunks
            if (buffer.length > boundary.length + 4) {
              buffer.removeRange(0, buffer.length - boundary.length - 4);
            }
            break;
          }
          
          // Found boundary, remove everything up to and including it
          buffer.removeRange(0, boundaryIndex + boundary.length);
          
          // Skip CRLF after boundary
          if (buffer.length >= 2 && buffer[0] == 13 && buffer[1] == 10) {
            buffer.removeRange(0, 2);
          }
          
          inHeaders = true;
        } else if (inHeaders) {
          // Looking for end of headers (CRLF CRLF)
          final headersEndIndex = _findBytesInBuffer(buffer, crlfcrlf, 0);
          if (headersEndIndex == -1) {
            // Need more data
            break;
          }
          
          // Extract headers
          final headerBytes = buffer.sublist(0, headersEndIndex);
          currentHeaders = utf8.decode(headerBytes);
          buffer.removeRange(0, headersEndIndex + 4);
          
          // Extract filename and prepare temp file for upload
          final filename = extractFilename(currentHeaders);
          if (filename != null && filename.isNotEmpty) {
            targetFilename = filename;
            // Write to temp file first with unique name to avoid conflicts
            final tempFileName = '${DateTime.now().millisecondsSinceEpoch}_$filename';
            currentTempFile = File('${tempDir.path}/$tempFileName');
            currentFileSink = currentTempFile.openWrite();
            contentBytesWritten = 0;
          }
          
          inHeaders = false;
          inContent = true;
        } else if (inContent) {
          // Look for next boundary
          final nextBoundaryIndex = _findBytesInBuffer(buffer, boundary, 0);
          
          if (nextBoundaryIndex == -1) {
            // No boundary found yet, write what we can safely write
            // Keep last few bytes in buffer in case boundary is split
            if (buffer.length > boundary.length + 4) {
              final safeLength = buffer.length - boundary.length - 4;
              if (currentFileSink != null) {
                currentFileSink.add(buffer.sublist(0, safeLength));
                contentBytesWritten += safeLength;
              }
              buffer.removeRange(0, safeLength);
            }
            break;
          } else {
            // Found next boundary
            // Write content up to CRLF before boundary
            var contentEnd = nextBoundaryIndex - 2;
            if (contentEnd < 0) contentEnd = 0;
            
            if (currentFileSink != null && currentTempFile != null && 
                currentHeaders != null && targetFilename != null && contentEnd > 0) {
              currentFileSink.add(buffer.sublist(0, contentEnd));
              contentBytesWritten += contentEnd;
              
              // Close temp file
              await currentFileSink.close();
              
              // Move from temp to final location (atomic operation)
              final finalFile = File('$outputDirectory/$targetFilename');
              await currentTempFile.rename(finalFile.path);
              
              // Save part info with final file location
              parts.add(StreamedMultipartPart(
                headers: currentHeaders,
                filename: extractFilename(currentHeaders),
                file: finalFile,
                size: contentBytesWritten,
              ));
              
              currentFileSink = null;
              currentTempFile = null;
              targetFilename = null;
              currentHeaders = null;
            }
            
            // Remove content from buffer
            buffer.removeRange(0, nextBoundaryIndex);
            inContent = false;
          }
        }
      }
    }
    
    // Clean up any open file handles and temp files on error
    if (currentFileSink != null) {
      await currentFileSink.close();
      // Delete incomplete temp file if upload was interrupted
      if (currentTempFile != null && await currentTempFile.exists()) {
        await currentTempFile.delete();
      }
    }
    
    return parts;
  }

  /// Extract filename from multipart headers
  static String? extractFilename(String headers) {
    final filenameMatch = RegExp(r'filename="([^"]+)"').firstMatch(headers);
    return filenameMatch?.group(1);
  }

  /// Find a byte sequence in a larger byte array
  static int _findBytes(List<int> haystack, List<int> needle, int start) {
    for (int i = start; i <= haystack.length - needle.length; i++) {
      bool found = true;
      for (int j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) {
          found = false;
          break;
        }
      }
      if (found) return i;
    }
    return -1;
  }

  /// Find bytes in a buffer (optimized for small buffers)
  static int _findBytesInBuffer(List<int> buffer, List<int> needle, int start) {
    return _findBytes(buffer, needle, start);
  }
}

