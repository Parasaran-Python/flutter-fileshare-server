# Flutter HTTP File Server

A beautiful and modern Flutter application that runs an HTTP server with file hosting, drag-and-drop upload, and IP whitelisting capabilities.

## Features

✨ **HTTP Server Management**
- Start/Stop server from the app UI
- Configurable port number
- Real-time server status display
- Automatic WiFi IP detection
- Prevents phone from sleeping while server is running

📁 **File Hosting**
- List all shared files with direct download links
- Beautiful web interface with modern gradient design
- File size display
- Easy file management
- **Streaming downloads for large files** - efficient memory usage
- **HTTP Range request support** - enables multi-threaded/resumable downloads

📤 **File Upload**
- Drag-and-drop file upload interface
- Click to browse and upload
- Real-time upload progress bar with percentage
- **Live upload speed indicator** (KB/s, MB/s)
- **Shows uploaded size / total size** (e.g., "15.3 MB / 50 MB")
- Cancel upload button during transfer
- JSON API responses
- Multiple file support
- Supports all file types (binary and text files)
- Sequential upload with visual feedback
- **Streaming upload for large files** - no memory bloat, handles multi-GB files efficiently
- **Atomic file uploads** - files written to temp directory first, moved to final location only after successful upload

🔒 **IP Whitelisting**
- Whitelist specific IP addresses for access control
- Add/remove IPs from the UI
- Empty whitelist allows all connections
- Localhost always allowed

🎨 **Modern UI**
- Material Design 3
- Responsive layout
- Beautiful cards and animations
- Easy-to-use controls
- Copy file path to clipboard with one tap
- Copy server URL to clipboard
- Copy direct file URLs for sharing
- Delete files with confirmation dialog (app UI only)
- Auto-refresh: App UI updates every 3 seconds, web page updates after upload

## Getting Started

### Prerequisites

- Flutter SDK (3.9.2 or higher)
- Dart SDK
- Android Studio / Xcode (for mobile deployment)

### Installation

1. Clone or download this repository
2. Navigate to the project directory
3. Install dependencies:

```bash
flutter pub get
```

### Running the App

```bash
flutter run
```

Or use your IDE's run button.

## How to Use

### 1. Start the Server

1. Open the app
2. (Optional) Configure the port number (default: 8080)
3. Tap the **"Start Server"** button
4. The server URL will be displayed (e.g., `http://192.168.1.100:8080`)
5. Your phone will stay awake automatically while the server is running

### 2. Access the Web Interface

- Open a web browser on any device on the same network
- Navigate to the server URL displayed in the app
- You'll see a beautiful page with:
  - File upload section (drag & drop or click)
  - List of available files with download links

### 3. Upload Files

**Via Web Interface:**
- Drag files onto the drop zone
- Or click the drop zone to browse files
- Watch real-time upload progress:
  - Percentage (e.g., "85%")
  - Speed (e.g., "2.45 MB/s")
  - Size uploaded / total (e.g., "42.5 MB / 50 MB")
- Files are automatically uploaded and the list refreshes dynamically

### 4. Download Files

- Click any file name in the web interface
- File will download directly
- **Multi-threaded downloads supported**: Use download managers like IDM, aria2, or wget with `-c` flag for faster, resumable downloads
- **Resume downloads**: Interrupted downloads can be resumed from where they left off

### 5. IP Whitelisting (Optional)

1. In the app, scroll to the **"IP Whitelist"** section
2. Enter an IP address (e.g., `192.168.1.50`)
3. Tap the **+** button to add
4. Only whitelisted IPs can access the server
5. Leave empty to allow all connections

### 6. Manage Files

**Copy File URL:**
- Click the link icon (🔗) next to any file to copy its direct download URL
- Share this URL with others to let them download the file directly

**Delete Files (App UI Only):**
- Click the delete icon (🗑️) next to any file in the app
- Confirm the deletion in the dialog
- File is removed immediately
- Both app UI and web page auto-refresh to show changes

**Cancel Upload:**
- During file upload on web page, click the "✖ Cancel Upload" button
- Upload will be stopped immediately

### 7. Stop the Server

- Tap the **"Stop Server"** button when done

## File Storage Location

Files are stored in the app's external media directory:
- **Android**: `/storage/emulated/0/Android/media/com.example.flutter_host_server/files/shared_files/`
- **iOS**: App's document directory
- **Desktop**: `Documents/FlutterFileServer/`

The exact path is displayed in the "Shared Files" section of the app.

**Android Note**: This is the app's external media directory, which means:
- Files are stored in the media folder (not data folder)
- No special permissions required
- Files are deleted when you uninstall the app
- You can access files via USB or file manager (Android/media folder)
- Better suited for media files (videos, images, audio, etc.)

## Permissions

### Android
The app requires the following permissions:
- `INTERNET` - To run the HTTP server
- `ACCESS_NETWORK_STATE` - To detect network status
- `ACCESS_WIFI_STATE` - To get WiFi information
- `ACCESS_FINE_LOCATION` - To get WiFi IP address (for getting WiFi network info)
- `ACCESS_COARSE_LOCATION` - For network info

**Note**: App-specific external storage doesn't require additional storage permissions. The location permission is only needed to get your WiFi IP address for displaying the server URL.

### iOS
The app requires:
- Local Network Usage - To run the HTTP server
- Location When In Use - To get WiFi network information

## Architecture

- **Framework**: Flutter
- **HTTP Server**: Shelf package
- **File Storage**: path_provider package
- **Network Info**: network_info_plus package
- **UI**: Material Design 3

## Security Considerations

⚠️ **Important Security Notes:**

1. **Network Security**: This server runs on your local network. Anyone with access to your network can potentially connect (unless you use IP whitelisting).

2. **IP Whitelisting**: For better security, always use IP whitelisting to restrict access to trusted devices.

3. **HTTPS**: This server uses HTTP (not HTTPS), so data is not encrypted in transit. Don't use it for sensitive files on untrusted networks.

4. **Firewall**: Some networks may block incoming connections. Check your firewall settings if you can't connect.

5. **Production Use**: This is designed for local/development use. For production, consider using proper authentication and HTTPS.

6. **File Handling**: Filenames are properly URL encoded/decoded and HTML escaped to prevent injection attacks and handle special characters correctly.

## Troubleshooting

### Can't access the server from other devices

- Ensure both devices are on the same WiFi network
- Check your firewall settings
- Try disabling any VPN
- Verify the IP address and port are correct

### Server won't start

- Check if the port is already in use
- Try a different port number (e.g., 8081, 8082)
- Ensure you have network permissions

### Files not appearing

- Tap the refresh button in the "Shared Files" section
- Check the file storage location (shown in the app)
- Restart the server
- You can access the files via USB or a file manager that can browse Android/data folders

### Upload not working

- Check file size (very large files may take time)
- Ensure you have storage space
- Try refreshing the web page

### Phone still goes to sleep

- The wakelock is only active when the server is running
- Make sure you've started the server
- Some devices have aggressive power management that may override wakelock
- Check your device's battery optimization settings

## Development

### Project Structure

```
lib/
  ├── main.dart                          # App entry point
  ├── screens/
  │   └── server_home_page.dart          # Main UI screen
  ├── services/
  │   └── http_server_service.dart       # HTTP server logic
  └── utils/
      ├── html_generator.dart            # Web page generation
      └── multipart_parser.dart          # File upload parsing
android/                                 # Android-specific configuration
ios/                                     # iOS-specific configuration
windows/                                 # Windows-specific configuration
linux/                                   # Linux-specific configuration
macos/                                   # macOS-specific configuration
```

## API Documentation

### Upload Endpoint

**POST** `/upload`

Uploads a file to the server with multipart/form-data.

**Response:**
```json
{
  "success": true,
  "message": "File uploaded successfully",
  "filename": "example.jpg",
  "size": 12345
}
```

**Error Response:**
```json
{
  "success": false,
  "message": "Error description"
}
```

### Download Endpoint

**GET** `/files/{filename}`

Downloads a file from the server. The filename is URL-encoded.

**Headers:**
- `Accept-Ranges: bytes` - Always present to indicate range request support
- `Content-Range: bytes <start>-<end>/<total>` - Present in 206 responses
- `Content-Length: <size>` - Size of the response (full file or partial)
- `Content-Disposition: attachment; filename="<name>"` - Download filename
- `Content-Type: application/octet-stream` - Binary file type

**Range Requests:**
The server supports HTTP Range requests for multi-threaded and resumable downloads.

**Request Header:**
- `Range: bytes=<start>-<end>` - Request a specific byte range

**Examples:**
- `Range: bytes=0-499` - First 500 bytes
- `Range: bytes=500-999` - Bytes 500-999
- `Range: bytes=500-` - From byte 500 to end
- `Range: bytes=-500` - Last 500 bytes

**Response Codes:**
- `200 OK` - Full file (no range requested)
- `206 Partial Content` - Partial file (range requested)
- `416 Range Not Satisfiable` - Invalid range

**Response:** Binary file data with `Content-Disposition` header.

### File List Endpoint

**GET** `/api/files`

Gets the current list of files on the server (used for dynamic refresh).

**Response:**
```json
{
  "success": true,
  "files": [
    {
      "filename": "example.jpg",
      "size": 12345
    },
    {
      "filename": "document.pdf",
      "size": 98765
    }
  ]
}
```

**Note:** File deletion is only available from the app UI for security reasons.

## Architecture

The app follows a clean, modular architecture:

- **`main.dart`**: Minimal entry point, just initializes the app
- **`screens/`**: UI layer with all Flutter widgets
  - `server_home_page.dart`: Main screen with server controls and file management
- **`services/`**: Business logic layer
  - `http_server_service.dart`: Handles HTTP server lifecycle, request routing, and IP whitelisting
- **`utils/`**: Utility classes
  - `html_generator.dart`: Generates the web interface HTML with CSS and JavaScript
  - `multipart_parser.dart`: Parses multipart/form-data for binary file uploads

This separation makes the code maintainable, testable, and easy to extend.

### Key Dependencies

- `shelf: ^1.4.1` - HTTP server framework
- `shelf_static: ^1.1.2` - Static file serving  
- `path_provider: ^2.1.1` - File system paths (includes getExternalStorageDirectory)
- `path: ^1.9.0` - Path manipulation
- `network_info_plus: ^5.0.2` - Network information
- `wakelock_plus: ^1.2.5` - Prevents phone from sleeping while server runs

## Contributing

Feel free to submit issues and enhancement requests!

## License

This project is open source and available under the MIT License.

## Screenshots

### App UI
- Server status with URL display
- Start/Stop controls
- IP whitelist management
- Shared files list

### Web Interface
- Modern gradient design
- Drag-and-drop upload
- File listing with sizes
- Responsive layout

## Future Enhancements

Potential features for future versions:
- [ ] HTTPS support
- [ ] User authentication
- [ ] File deletion from web interface
- [ ] Upload progress indicator
- [ ] QR code for easy URL sharing
- [ ] File preview
- [ ] Folder support
- [ ] Search functionality

## Support

For issues and questions, please open an issue on the repository.

---

Made with ❤️ using Flutter
