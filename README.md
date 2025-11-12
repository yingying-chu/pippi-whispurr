# Pippi Whispurr - Pet Photo Calendar 🐾

An iOS app that automatically scans your iPhone photo library, identifies pet photos using AI, and displays them in an interactive calendar.

## Features

- **Automatic Pet Detection**: Uses Apple's Vision framework to identify dogs, cats, and other pets in your photos
- **Interactive Calendar**: Browse your pet photos by date with an intuitive calendar interface
- **Photo Gallery**: View all pet photos taken on a specific day
- **Detailed Photo View**: See full-resolution photos with metadata including confidence scores and timestamps
- **Privacy-First**: All processing happens on-device using iOS frameworks - no cloud uploading required

## How It Works

1. **Grant Permission**: The app requests access to your photo library
2. **Scan Library**: Tap "Scan Photo Library" to analyze all your photos
3. **AI Detection**: The Vision framework analyzes each photo to detect cats, dogs, and other pets
4. **Calendar Display**: Photos with detected pets are organized by date in the calendar
5. **Browse & View**: Click on any date to see all pet photos from that day

## Technical Details

### Architecture

- **SwiftUI**: Modern declarative UI framework
- **PhotoKit**: Access and manage photo library assets
- **Vision Framework**: On-device machine learning for pet detection
- **MVVM Pattern**: Clean separation of concerns with observable objects

### Key Components

- `PippiWhispurrApp.swift`: Main app entry point
- `PhotoManager.swift`: Manages photo library access and scanning
- `PetDetector.swift`: Handles AI-powered pet detection using Vision framework
- `PetPhoto.swift`: Data models for pet photos and dates
- `ContentView.swift`: Main view coordinating calendar and photo display
- `CalendarView.swift`: Interactive calendar with photo indicators
- `PhotoGridView.swift`: Grid layout for photos on selected dates
- `PhotoDetailView.swift`: Full-screen photo viewer with metadata
- `ScannerView.swift`: Progress tracking during library scanning

### Requirements

- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+
- An iOS device or simulator with photo library access

## Setup Instructions

1. **Open in Xcode**:
   ```bash
   open PippiWhispurr.xcodeproj
   ```

2. **Configure Signing**:
   - Select the PippiWhispurr target in Xcode
   - Go to "Signing & Capabilities"
   - Select your development team

3. **Build and Run**:
   - Select your target device or simulator
   - Press Cmd+R to build and run

4. **Grant Permissions**:
   - On first launch, grant photo library access
   - The app requires read access to scan and display photos

## Usage

### First-Time Setup
1. Launch the app
2. Grant photo library permissions when prompted
3. Tap "Scan Photo Library" to begin analysis
4. Wait for the scan to complete (progress shown)

### Browsing Photos
- Navigate between months using the arrows in the calendar
- Days with pet photos are highlighted with a blue dot
- Tap any highlighted day to view photos from that date
- Tap a photo thumbnail to see it in full screen

### Understanding Detection
- Each photo shows a confidence score (percentage)
- Pet type emoji indicates the detected animal (🐕 dog, 🐱 cat, 🐾 other)
- Only photos with >60% confidence are included

## Privacy

- **100% On-Device**: All photo analysis happens locally using Apple's Vision framework
- **No Cloud Upload**: Your photos never leave your device
- **Standard iOS Permissions**: Uses standard PhotoKit permissions
- **No Data Collection**: The app doesn't collect or transmit any data

## Future Enhancements

Potential features for future versions:
- Filter by pet type (dogs only, cats only, etc.)
- Export pet photo collections
- Create shareable photo books or slideshows
- Custom pet names and tagging
- iCloud sync for pet photo metadata
- Widget support for recent pet photos

## License

This project is open source and available for personal and educational use.

## Support

For issues or questions, please open an issue in the repository.

---

Made with ❤️ for pet lovers everywhere