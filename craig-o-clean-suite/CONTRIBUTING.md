# Contributing to Craig-O-Clean Suite

Thank you for your interest in contributing to Craig-O-Clean Suite! This document provides guidelines for contributing to the project.

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment for all contributors.

## Development Setup

### Prerequisites

- **Android**: JDK 17+, Android Studio
- **Windows**: .NET 8 SDK, Visual Studio 2022+
- **Linux**: Flutter SDK 3.19+, Linux dev dependencies
- **Backend**: Node.js 20+, Docker

### Repository Structure

```
craig-o-clean-suite/
├── shared/        # Shared schemas and configurations
├── android/       # Android app (Kotlin/Compose)
├── windows/       # Windows app (C#/WinUI 3)
├── linux/         # Linux app (Flutter)
├── backend/       # Stripe billing backend
└── .github/       # CI/CD workflows
```

### Setting Up Each Platform

#### Android

```bash
cd android
./gradlew build
```

#### Windows

```bash
cd windows
dotnet restore
dotnet build
```

#### Linux

```bash
cd linux
flutter pub get
flutter build linux
```

#### Backend

```bash
cd backend
npm install
cp .env.example .env
# Configure your .env
docker-compose up -d  # Start Postgres
npm run dev
```

## Making Changes

### Branching Strategy

- `main` - Production-ready code
- `develop` - Integration branch
- `feature/*` - Feature branches
- `fix/*` - Bug fix branches
- `release/*` - Release preparation

### Commit Messages

Follow conventional commits:

```
type(scope): description

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Formatting
- `refactor`: Code restructuring
- `test`: Tests
- `chore`: Maintenance

Examples:
```
feat(android): add process search functionality
fix(windows): resolve tray icon not showing on startup
docs(linux): update Flatpak packaging instructions
```

### Pull Requests

1. Create a feature branch from `develop`
2. Make your changes
3. Ensure tests pass
4. Update documentation if needed
5. Submit a PR to `develop`

PR titles should follow the same format as commit messages.

## Testing

### Android

```bash
cd android
./gradlew test                    # Unit tests
./gradlew connectedAndroidTest    # Instrumented tests
```

### Windows

```bash
cd windows
dotnet test
```

### Linux

```bash
cd linux
flutter test                      # Unit tests
flutter test integration_test     # Integration tests
```

### Backend

```bash
cd backend
npm test                         # Unit tests
npm run test:integration         # Integration tests
```

## Code Style

### Android (Kotlin)

- Follow [Kotlin coding conventions](https://kotlinlang.org/docs/coding-conventions.html)
- Use ktlint for formatting

### Windows (C#)

- Follow [C# coding conventions](https://docs.microsoft.com/en-us/dotnet/csharp/fundamentals/coding-style/coding-conventions)
- Use .editorconfig settings

### Linux (Dart/Flutter)

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
- Run `flutter analyze` before submitting

### Backend (TypeScript)

- Use ESLint and Prettier
- Run `npm run lint` before submitting

## Architecture Guidelines

### Shared Patterns

All platforms should implement:

1. **Service Layer**: `SystemMetricsService`, `ProcessManagerService`, `EntitlementManager`
2. **Feature Gating**: Consistent free/trial/paid feature access
3. **Error Handling**: Graceful degradation, user-friendly messages
4. **Accessibility**: Screen reader support, keyboard navigation

### Platform-Specific

- **Android**: Respect OS restrictions on process management
- **Windows**: Use proper elevation for privileged operations
- **Linux**: Handle different desktop environments gracefully

## Documentation

- Update relevant docs when making changes
- Include JSDoc/KDoc/XML comments for public APIs
- Update CHANGELOG.md for user-facing changes

## Security

- Never commit secrets or API keys
- Use secure storage for tokens
- Validate all user input
- Follow OWASP guidelines

### Reporting Security Issues

Please report security vulnerabilities privately to the maintainers rather than opening public issues.

## Releases

Releases are managed by maintainers. Version numbers follow semantic versioning:

- Major: Breaking changes
- Minor: New features
- Patch: Bug fixes

## Questions?

- Open an issue for bugs or feature requests
- Use discussions for questions and ideas

Thank you for contributing!
