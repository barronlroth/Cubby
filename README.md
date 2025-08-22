# 📦 Cubby

<div align="center">
  <img src="Cubby/Assets.xcassets/AppIcon.appiconset/AppIcon.png" alt="Cubby Logo" width="120" height="120">
  
  **A home inventory management app that helps you track where everything is stored**
  
  [![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
  [![Platform](https://img.shields.io/badge/Platform-iOS%2017.0%2B-blue.svg)](https://developer.apple.com/ios/)
  [![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-blue.svg)](https://developer.apple.com/xcode/swiftui/)
  [![SwiftData](https://img.shields.io/badge/SwiftData-iOS%2017-green.svg)](https://developer.apple.com/xcode/swiftdata/)
  [![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
</div>

## 🎯 Overview

Ever wondered "Do I already own this?" while shopping? Or spent hours searching for something you know you have but can't remember where? **Cubby** solves these everyday problems by helping you catalog and locate your belongings across multiple homes and storage locations.

### ✨ Key Features

- 🏠 **Multiple Homes** - Track items across different properties
- 📍 **Hierarchical Storage** - Organize with nested locations (Home → Bedroom → Closet → Top Shelf)
- 📸 **Visual Inventory** - Add photos to easily identify items
- 🔍 **Smart Search** - Quickly find any item across all locations
- 📱 **Native iOS Design** - Built with SwiftUI for a seamless Apple experience
- ☁️ **CloudKit Ready** - Infrastructure for future sync capabilities
- 🔄 **Undo Support** - Recover accidentally deleted items

## 📱 Screenshots

<div align="center">
  <i>Screenshots coming soon!</i>
</div>

## 🚀 Getting Started

### Prerequisites

- macOS 14.0 or later
- Xcode 15.0 or later
- iOS 17.0+ deployment target

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/barronlroth/Cubby.git
   cd Cubby
   ```

2. **Open in Xcode**
   ```bash
   open Cubby.xcodeproj
   ```

3. **Build and Run**
   - Select your target device or simulator
   - Press `Cmd + R` to build and run

### Building from Command Line

```bash
# Build the project
xcodebuild -project Cubby.xcodeproj -scheme Cubby build

# Run tests
xcodebuild -project Cubby.xcodeproj -scheme Cubby test

# Build for release
xcodebuild -project Cubby.xcodeproj -scheme Cubby -configuration Release build
```

## 📖 Usage

### First Launch
1. **Create Your First Home** - Name your primary residence or storage location
2. **Add Storage Locations** - Create a hierarchy of storage areas (rooms, furniture, containers)
3. **Add Items** - Catalog your belongings with photos and descriptions

### Organization Tips
- Start with broad categories (rooms) and get more specific (drawers, shelves)
- Use consistent naming conventions for easier searching
- Take clear photos for visual identification
- Add descriptions for items that look similar

### Workflow Example
```
Home: "Main Residence"
  └── Bedroom
      └── Closet
          └── Top Shelf
              └── Winter Clothes Box
                  └── Items: Wool Sweater, Ski Gloves, Winter Hat
```

## 🏗️ Architecture

### Tech Stack
- **SwiftUI** - Modern declarative UI framework
- **SwiftData** - Apple's latest persistence framework with automatic CloudKit sync capabilities
- **Swift Testing** - New testing framework for robust unit tests
- **PhotosUI** - Native photo selection and capture
- **NSCache** - Efficient photo caching (50MB limit)

### Project Structure
```
Cubby/
├── Models/           # SwiftData models
├── Views/            # SwiftUI views
├── Services/         # Business logic
├── ViewModels/       # View-specific logic
└── Utils/           # Helper utilities
```

### Key Design Patterns
- **MVVM Architecture** - Clean separation of concerns
- **Dependency Injection** - Via SwiftUI environment
- **Reactive UI** - Automatic updates with @Query
- **Protocol-Oriented** - Testable and modular code

## 🧪 Testing

Run the test suite:
```bash
xcodebuild -project Cubby.xcodeproj -scheme Cubby test
```

### Test Coverage
- Unit tests for models and business logic
- UI tests for critical user flows
- Performance tests for large datasets

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Development Guidelines
- Follow Swift API Design Guidelines
- Write unit tests for new features
- Update documentation as needed
- Keep commits atomic and descriptive

## 📋 Roadmap

- [ ] **v1.0** - Core inventory management
  - [x] Multiple homes support
  - [x] Hierarchical storage locations
  - [x] Photo management
  - [x] Search functionality
  - [ ] Comprehensive testing
  - [ ] App Store release

- [ ] **v2.0** - Sync & Sharing
  - [ ] CloudKit sync across devices
  - [ ] Family sharing
  - [ ] Export/Import functionality
  
- [ ] **v3.0** - Advanced Features
  - [ ] Barcode scanning
  - [ ] Purchase tracking
  - [ ] Maintenance reminders
  - [ ] Categories and tags

## 🐛 Known Issues

- Performance not tested with 1000+ items
- Empty storage locations don't appear in home view (by design)
- See [Issues](https://github.com/barronlroth/Cubby/issues) for more

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👏 Acknowledgments

- Built with Swift and SwiftUI
- App icon features an adorable bear cub crafted with AI
- Inspired by the universal struggle of finding things

## 📞 Contact

Barron Roth - [@barronlroth](https://github.com/barronlroth)

Project Link: [https://github.com/barronlroth/Cubby](https://github.com/barronlroth/Cubby)

---

<div align="center">
  Made with ❤️ and Swift
</div>