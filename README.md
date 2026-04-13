# MaxHype

A modern Flutter fitness tracking application with workout progress visualization and monthly analytics.

## Features

- **Workout Cards**: Horizontal scrollable workout cards with recovery status indicators
- **Monthly Calendar**: Visual workout tracking with completion percentage
- **Progress Charts**: Interactive KCAL and Volume charts with monthly navigation
- **Dark Theme**: Modern UI with custom color scheme and glow effects
- **Clean Architecture**: BLoC pattern with dependency injection

## Quick Start

### Prerequisites
- Flutter SDK (3.0+)
- Dart SDK
- iOS Simulator / Android Emulator

### Installation

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run
```

### iOS Simulator
```bash
flutter emulators --launch apple_ios_simulator
flutter run
```

### Android
```bash
flutter run
```

## Documentation

Comprehensive documentation is available in the `/docs` directory:

- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - System architecture, component structure, and scaling patterns
- **[IMPLEMENTATION.md](docs/IMPLEMENTATION.md)** - Implementation details, project structure, and completed features
- **[architecture.puml](docs/architecture.puml)** - PlantUML architecture diagram source

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── core/                        # Dependency injection & factories
├── models/                      # Data models
├── repositories/                # Repository pattern interfaces
├── screens/home/                # Home screen with BLoC
├── widgets/                     # Reusable UI components
├── data/                        # Mock data generators
└── theme/                       # App-wide theming
```

## Architecture Overview

The application follows **Clean Architecture** with **BLoC pattern**:

```
UI Layer (Widgets)
    ↓
BLoC Layer (Business Logic)
    ↓
Repository Layer (Data Interface)
    ↓
Data Layer (Mock/API)
```

For detailed architecture information, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Dependencies

- `flutter_bloc` - State management
- `get_it` - Dependency injection
- `fl_chart` - Chart visualizations
- `provider` - State management utilities
- `intl` - Date formatting

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is a private Flutter application.
