# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Cubby is a native iOS/macOS SwiftUI application that uses SwiftData for persistence. It's a simple item management app with timestamped entries.

## Essential Commands

### Building and Running
```bash
# Build the project
xcodebuild -project Cubby.xcodeproj -scheme Cubby build

# Run tests
xcodebuild -project Cubby.xcodeproj -scheme Cubby test

# Clean build folder
xcodebuild -project Cubby.xcodeproj -scheme Cubby clean

# Run specific test
xcodebuild -project Cubby.xcodeproj -scheme Cubby test-without-building -only-testing:CubbyTests/CubbyTests/testExample
```

### Development Workflow
- Primary development is done through Xcode IDE
- Use Xcode's built-in SwiftUI preview for rapid UI development
- SwiftData models automatically generate database schema

## Architecture

### Core Technologies
- **SwiftUI**: Declarative UI framework
- **SwiftData**: Modern persistence framework (replaces Core Data)
- **Swift Testing**: New testing framework for unit tests
- **CloudKit**: Configured for cloud sync (entitlements present)

### Key Files and Responsibilities
- `CubbyApp.swift`: App entry point, configures SwiftData ModelContainer
- `ContentView.swift`: Main UI with NavigationSplitView, handles item list display and CRUD operations
- `Item.swift`: SwiftData model using @Model macro

### Data Flow
1. SwiftData ModelContainer is created in CubbyApp with Item schema
2. Container is injected into SwiftUI environment
3. Views use @Query to reactively fetch data
4. @Environment(\.modelContext) provides access for mutations

### Testing Strategy
- Unit tests use Swift Testing framework (modern approach with @Test macro)
- UI tests use XCTest framework for automation
- Tests are located in CubbyTests/ and CubbyUITests/ directories

## Important Considerations

### SwiftData Requirements
- Requires iOS 17.0+ / macOS 14.0+
- Models must use @Model macro
- Properties need explicit initialization or default values
- Relationships are defined using standard Swift properties

### SwiftUI Best Practices
- Use @Query for reactive data fetching
- Leverage environment injection for model context
- Follow NavigationSplitView pattern for iPad/Mac compatibility

### CloudKit Integration
- App has CloudKit entitlements configured
- Remote notification background mode enabled
- Ensure proper container identifiers when implementing sync