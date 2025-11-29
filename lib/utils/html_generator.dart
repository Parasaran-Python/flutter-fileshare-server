import 'dart:io';
import 'package:path/path.dart' as path;

/// Generates HTML pages for the web interface
class HtmlGenerator {
  /// Generate the main file server page with upload and file listing
  static String generateMainPage(List<FileSystemEntity> files) {
    final fileListHtml = _generateFileList(files);

    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>File Share Server</title>
    <style>
        ${_getStyles()}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📁 File Share Server</h1>
            <p>Drag & drop files or click to upload</p>
        </div>
        
        <div class="content">
            <div class="section">
                <h2>📤 Upload Files</h2>
                <div class="drop-zone" id="dropZone">
                    <p>🎯 Drop files here</p>
                    <p style="font-size: 0.9em; color: #666;">or click to browse</p>
                    <input type="file" id="fileInput" class="file-input" multiple>
                </div>
                <div id="uploadsContainer" class="uploads-container"></div>
                <div id="uploadStatus" class="upload-status"></div>
            </div>
            
            <div class="section">
                <h2>📥 Available Files (${files.length})</h2>
                ${files.isEmpty ? '<div class="empty-state">No files available. Upload some files to get started!</div>' : '<ul class="file-list">$fileListHtml</ul>'}
            </div>
        </div>
    </div>
    
    <script>
        ${_getJavaScript()}
    </script>
</body>
</html>
''';
  }

  /// Generate file list HTML
  static String _generateFileList(List<FileSystemEntity> files) {
    return files.map((file) {
      final filename = path.basename(file.path);
      final fileSize = (file as File).lengthSync();
      final sizeStr = _formatBytes(fileSize);
      // URL encode the filename for the link
      final encodedFilename = Uri.encodeComponent(filename);
      // HTML escape the filename for display to prevent XSS
      final escapedFilename = _htmlEscape(filename);
      return '<li><a href="/files/$encodedFilename" download>$escapedFilename</a> <span style="color: #666;">($sizeStr)</span></li>';
    }).join('\n');
  }

  /// Format bytes to human-readable size
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// HTML escape text to prevent XSS
  static String _htmlEscape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  /// CSS styles for the web interface
  static String _getStyles() {
    return '''
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 900px;
            margin: 0 auto;
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        
        .header h1 {
            font-size: 2em;
            margin-bottom: 10px;
        }
        
        .content {
            padding: 40px;
        }
        
        .section {
            margin-bottom: 40px;
        }
        
        .section h2 {
            color: #667eea;
            margin-bottom: 20px;
            font-size: 1.5em;
            border-bottom: 2px solid #667eea;
            padding-bottom: 10px;
        }
        
        .drop-zone {
            border: 3px dashed #667eea;
            border-radius: 15px;
            padding: 60px 20px;
            text-align: center;
            background: #f8f9ff;
            cursor: pointer;
            transition: all 0.3s ease;
        }
        
        .drop-zone:hover, .drop-zone.drag-over {
            background: #667eea;
            color: white;
            transform: scale(1.02);
        }
        
        .drop-zone.drag-over {
            border-color: #764ba2;
        }
        
        .drop-zone p {
            font-size: 1.2em;
            margin-bottom: 10px;
        }
        
        .file-input {
            display: none;
        }
        
        .file-list {
            list-style: none;
        }
        
        .file-list li {
            padding: 15px;
            margin-bottom: 10px;
            background: #f8f9ff;
            border-radius: 10px;
            transition: all 0.3s ease;
        }
        
        .file-list li:hover {
            background: #667eea;
            transform: translateX(10px);
        }
        
        .file-list li:hover a {
            color: white;
        }
        
        .file-list a {
            color: #667eea;
            text-decoration: none;
            font-weight: 500;
            font-size: 1.1em;
        }
        
        .empty-state {
            text-align: center;
            padding: 40px;
            color: #999;
            font-style: italic;
        }
        
        .uploads-container {
            margin-top: 20px;
        }
        
        .upload-item {
            background: #f8f9ff;
            border: 1px solid #667eea;
            border-radius: 10px;
            padding: 15px;
            margin-bottom: 15px;
            transition: all 0.3s ease;
        }
        
        .upload-item.completed {
            background: #d4edda;
            border-color: #28a745;
        }
        
        .upload-item.error {
            background: #f8d7da;
            border-color: #dc3545;
        }
        
        .upload-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 10px;
        }
        
        .upload-filename {
            font-weight: 600;
            color: #333;
            font-size: 1.1em;
            flex: 1;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }
        
        .upload-actions {
            display: flex;
            gap: 10px;
            align-items: center;
        }
        
        .upload-status-badge {
            padding: 4px 12px;
            border-radius: 12px;
            font-size: 0.85em;
            font-weight: 600;
        }
        
        .status-uploading {
            background: #667eea;
            color: white;
        }
        
        .status-completed {
            background: #28a745;
            color: white;
        }
        
        .status-error {
            background: #dc3545;
            color: white;
        }
        
        .cancel-button {
            background: #dc3545;
            color: white;
            border: none;
            padding: 6px 12px;
            border-radius: 5px;
            cursor: pointer;
            font-size: 0.85em;
            font-weight: bold;
            transition: background 0.3s ease;
        }
        
        .cancel-button:hover {
            background: #c82333;
        }
        
        .progress-bar {
            width: 100%;
            height: 24px;
            background: #e0e0e0;
            border-radius: 12px;
            overflow: hidden;
            margin-bottom: 8px;
        }
        
        .progress-fill {
            height: 100%;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            width: 0%;
            transition: width 0.3s ease;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-weight: bold;
            font-size: 0.85em;
        }
        
        .upload-details {
            display: flex;
            justify-content: space-between;
            font-size: 0.9em;
            color: #666;
        }
        
        .speed-text {
            color: #764ba2;
            font-weight: 500;
        }
        
        .eta-text {
            color: #667eea;
            font-weight: 500;
        }
        
        .size-text {
            color: #999;
        }
        
        .upload-status {
            margin-top: 20px;
            padding: 15px;
            border-radius: 10px;
            display: none;
        }
        
        .upload-status.success {
            background: #d4edda;
            color: #155724;
            display: block;
        }
        
        .upload-status.error {
            background: #f8d7da;
            color: #721c24;
            display: block;
        }
    ''';
  }

  /// JavaScript for the web interface
  static String _getJavaScript() {
    return '''
        const dropZone = document.getElementById('dropZone');
        const fileInput = document.getElementById('fileInput');
        const uploadsContainer = document.getElementById('uploadsContainer');
        const uploadStatus = document.getElementById('uploadStatus');
        
        // Track active uploads
        const activeUploads = new Map();
        
        dropZone.addEventListener('click', () => fileInput.click());
        
        dropZone.addEventListener('dragover', (e) => {
            e.preventDefault();
            dropZone.classList.add('drag-over');
        });
        
        dropZone.addEventListener('dragleave', () => {
            dropZone.classList.remove('drag-over');
        });
        
        dropZone.addEventListener('drop', (e) => {
            e.preventDefault();
            dropZone.classList.remove('drag-over');
            const files = e.dataTransfer.files;
            if (files.length > 0) {
                uploadFiles(files);
            }
        });
        
        fileInput.addEventListener('change', (e) => {
            if (e.target.files.length > 0) {
                uploadFiles(e.target.files);
            }
        });
        
        function uploadFiles(files) {
            // Upload all files in parallel
            const uploadPromises = [];
            
            for (let i = 0; i < files.length; i++) {
                uploadPromises.push(uploadFile(files[i]));
            }
            
            // Wait for all uploads to complete, then refresh file list
            Promise.allSettled(uploadPromises).then(() => {
                setTimeout(() => refreshFileList(), 1000);
            });
        }
        
        function formatBytes(bytes) {
            if (bytes < 1024) return bytes + ' B';
            if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
            if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
            return (bytes / (1024 * 1024 * 1024)).toFixed(1) + ' GB';
        }
        
        function formatSpeed(bytesPerSecond) {
            if (bytesPerSecond < 1024) return bytesPerSecond.toFixed(0) + ' B/s';
            if (bytesPerSecond < 1024 * 1024) return (bytesPerSecond / 1024).toFixed(2) + ' KB/s';
            return (bytesPerSecond / (1024 * 1024)).toFixed(2) + ' MB/s';
        }
        
        function formatTime(seconds) {
            if (seconds < 1) return '< 1s';
            if (seconds < 60) return Math.round(seconds) + 's';
            const minutes = Math.floor(seconds / 60);
            const remainingSeconds = Math.round(seconds % 60);
            if (minutes < 60) {
                return remainingSeconds > 0 ? minutes + 'm ' + remainingSeconds + 's' : minutes + 'm';
            }
            const hours = Math.floor(minutes / 60);
            const remainingMinutes = minutes % 60;
            return remainingMinutes > 0 ? hours + 'h ' + remainingMinutes + 'm' : hours + 'h';
        }
        
        function refreshFileList() {
            fetch('/api/files')
                .then(response => response.json())
                .then(data => {
                    if (data.success && data.files) {
                        const fileSection = document.querySelector('.section:last-child');
                        const filesCount = data.files.length;
                        
                        // Update the title
                        fileSection.querySelector('h2').textContent = '📥 Available Files (' + filesCount + ')';
                        
                        // Get the container after h2
                        const h2 = fileSection.querySelector('h2');
                        let container = h2.nextElementSibling;
                        
                        // Remove existing file list or empty state
                        if (container) {
                            container.remove();
                        }
                        
                        if (filesCount === 0) {
                            const emptyDiv = document.createElement('div');
                            emptyDiv.className = 'empty-state';
                            emptyDiv.textContent = 'No files available. Upload some files to get started!';
                            h2.after(emptyDiv);
                        } else {
                            const ul = document.createElement('ul');
                            ul.className = 'file-list';
                            
                            data.files.forEach(file => {
                                const encodedFilename = encodeURIComponent(file.filename);
                                const sizeStr = formatBytes(file.size);
                                
                                const li = document.createElement('li');
                                const a = document.createElement('a');
                                a.href = '/files/' + encodedFilename;
                                a.download = true;
                                a.textContent = file.filename;
                                
                                const span = document.createElement('span');
                                span.style.color = '#666';
                                span.textContent = ' (' + sizeStr + ')';
                                
                                li.appendChild(a);
                                li.appendChild(span);
                                ul.appendChild(li);
                            });
                            
                            h2.after(ul);
                        }
                    }
                })
                .catch(error => {
                    console.error('Error refreshing file list:', error);
                });
        }
        
        function uploadFile(file) {
            return new Promise((resolve, reject) => {
                const uploadId = Date.now() + '_' + Math.random();
                
                // Create upload item UI
                const uploadItem = document.createElement('div');
                uploadItem.className = 'upload-item';
                uploadItem.id = 'upload_' + uploadId;
                
                uploadItem.innerHTML = \`
                    <div class="upload-header">
                        <div class="upload-filename" title="\${file.name}">\${file.name}</div>
                        <div class="upload-actions">
                            <span class="upload-status-badge status-uploading">Uploading...</span>
                            <button class="cancel-button" onclick="cancelUpload('\${uploadId}')">✖ Cancel</button>
                        </div>
                    </div>
                    <div class="progress-bar">
                        <div class="progress-fill" id="progress_\${uploadId}">0%</div>
                    </div>
                    <div class="upload-details">
                        <span class="speed-text" id="speed_\${uploadId}">0 KB/s</span>
                        <span class="eta-text" id="eta_\${uploadId}">ETA: Calculating...</span>
                        <span class="size-text" id="size_\${uploadId}">0 B / \${formatBytes(file.size)}</span>
                    </div>
                \`;
                
                uploadsContainer.appendChild(uploadItem);
                
                const formData = new FormData();
                formData.append('file', file);
                
                const xhr = new XMLHttpRequest();
                
                // Store XHR for potential cancellation
                activeUploads.set(uploadId, { xhr, uploadItem });
                
                // Speed tracking variables
                let lastTime = Date.now();
                let lastLoaded = 0;
                let speeds = [];
                
                // Track upload progress
                xhr.upload.addEventListener('progress', (e) => {
                    if (e.lengthComputable) {
                        const percentComplete = (e.loaded / e.total) * 100;
                        const progressFill = document.getElementById('progress_' + uploadId);
                        const speedText = document.getElementById('speed_' + uploadId);
                        const etaText = document.getElementById('eta_' + uploadId);
                        const sizeText = document.getElementById('size_' + uploadId);
                        
                        if (progressFill) {
                            progressFill.style.width = percentComplete + '%';
                            progressFill.textContent = Math.round(percentComplete) + '%';
                        }
                        
                        if (sizeText) {
                            sizeText.textContent = formatBytes(e.loaded) + ' / ' + formatBytes(e.total);
                        }
                        
                        // Calculate upload speed
                        const currentTime = Date.now();
                        const timeDiff = (currentTime - lastTime) / 1000;
                        const bytesDiff = e.loaded - lastLoaded;
                        
                        if (timeDiff > 0.1 && speedText) {
                            const currentSpeed = bytesDiff / timeDiff;
                            speeds.push(currentSpeed);
                            
                            if (speeds.length > 5) {
                                speeds.shift();
                            }
                            
                            const avgSpeed = speeds.reduce((a, b) => a + b, 0) / speeds.length;
                            speedText.textContent = formatSpeed(avgSpeed);
                            
                            // Calculate and display ETA
                            if (etaText && avgSpeed > 0) {
                                const remainingBytes = e.total - e.loaded;
                                const etaSeconds = remainingBytes / avgSpeed;
                                
                                if (percentComplete >= 99.9) {
                                    etaText.textContent = 'ETA: Almost done...';
                                } else {
                                    etaText.textContent = 'ETA: ' + formatTime(etaSeconds);
                                }
                            }
                            
                            lastTime = currentTime;
                            lastLoaded = e.loaded;
                        }
                    }
                });
                
                // Handle completion
                xhr.addEventListener('load', () => {
                    const upload = activeUploads.get(uploadId);
                    if (!upload) return;
                    
                    if (xhr.status === 200) {
                        try {
                            const response = JSON.parse(xhr.responseText);
                            
                            if (response.success) {
                                upload.uploadItem.classList.add('completed');
                                const badge = upload.uploadItem.querySelector('.upload-status-badge');
                                badge.className = 'upload-status-badge status-completed';
                                badge.textContent = '✅ Completed';
                                const cancelBtn = upload.uploadItem.querySelector('.cancel-button');
                                if (cancelBtn) cancelBtn.remove();
                                
                                // Remove completed upload after 3 seconds
                                setTimeout(() => {
                                    if (upload.uploadItem.parentNode) {
                                        upload.uploadItem.remove();
                                    }
                                    activeUploads.delete(uploadId);
                                }, 3000);
                                
                                resolve();
                            } else {
                                throw new Error(response.message || 'Upload failed');
                            }
                        } catch (e) {
                            handleUploadError(uploadId, 'Invalid response from server');
                            reject(e);
                        }
                    } else {
                        handleUploadError(uploadId, 'Upload failed with status: ' + xhr.status);
                        reject(new Error('Upload failed'));
                    }
                });
                
                // Handle errors
                xhr.addEventListener('error', () => {
                    handleUploadError(uploadId, 'Network error during upload');
                    reject(new Error('Network error'));
                });
                
                // Handle abort
                xhr.addEventListener('abort', () => {
                    const upload = activeUploads.get(uploadId);
                    if (upload && upload.uploadItem.parentNode) {
                        upload.uploadItem.remove();
                    }
                    activeUploads.delete(uploadId);
                    resolve(); // Resolve even on cancel to not block Promise.allSettled
                });
                
                // Send request
                xhr.open('POST', '/upload');
                xhr.send(formData);
            });
        }
        
        function handleUploadError(uploadId, message) {
            const upload = activeUploads.get(uploadId);
            if (!upload) return;
            
            upload.uploadItem.classList.add('error');
            const badge = upload.uploadItem.querySelector('.upload-status-badge');
            badge.className = 'upload-status-badge status-error';
            badge.textContent = '❌ Failed';
            
            const cancelBtn = upload.uploadItem.querySelector('.cancel-button');
            if (cancelBtn) cancelBtn.remove();
            
            // Remove failed upload after 5 seconds
            setTimeout(() => {
                if (upload.uploadItem.parentNode) {
                    upload.uploadItem.remove();
                }
                activeUploads.delete(uploadId);
            }, 5000);
        }
        
        function cancelUpload(uploadId) {
            const upload = activeUploads.get(uploadId);
            if (upload && upload.xhr) {
                upload.xhr.abort();
            }
        }
    ''';
  }
}

