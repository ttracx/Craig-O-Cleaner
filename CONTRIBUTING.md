# Contributing to Craig-O-Clean

Thank you for your interest in contributing to Craig-O-Clean! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Reporting Bugs](#reporting-bugs)
- [Requesting Features](#requesting-features)

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment. Please:

- Be respectful and considerate
- Welcome newcomers and help them get started
- Focus on constructive feedback
- Respect differing viewpoints and experiences
- Accept responsibility and apologize for mistakes

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/Craig-O-Cleaner.git
   cd Craig-O-Cleaner
   ```
3. **Add upstream remote**:
   ```bash
   git remote add upstream https://github.com/ttracx/Craig-O-Cleaner.git
   ```

## Development Setup

### Prerequisites

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later
- Git
- Basic knowledge of Swift and SwiftUI

### Building for Development

1. Open the project in Xcode:
   ```bash
   open Craig-O-Clean.xcodeproj
   ```

2. Select the "Craig-O-Clean" scheme
3. Choose "My Mac" as the destination
4. Press ⌘B to build or ⌘R to run

## Making Changes

### Branching Strategy

1. **Create a feature branch** from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Keep your branch up to date**:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

### Branch Naming Convention

- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation changes
- `refactor/` - Code refactoring
- `test/` - Adding tests
- `chore/` - Maintenance tasks

Examples:
- `feature/cpu-monitoring`
- `fix/memory-leak-in-process-manager`
- `docs/update-readme`

## Coding Standards

### Swift Style Guide

Follow the [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/):

1. **Naming**:
   - Use clear, descriptive names
   - Prefer clarity over brevity
   - Use camelCase for variables and functions
   - Use PascalCase for types and protocols

2. **Formatting**:
   - Indent with 4 spaces (not tabs)
   - Maximum line length: 120 characters
   - Use blank lines to separate logical sections

3. **Code Organization**:
   - Group related code together
   - Use MARK comments for organization
   - Keep files focused and manageable

### SwiftUI Best Practices

- Keep views small and focused
- Extract reusable components
- Use `@State` for view-local state
- Use `@StateObject` for observable objects created by the view
- Use `@ObservedObject` for observable objects passed in
- Avoid complex logic in view bodies

### Example

```swift
// MARK: - Process Manager

class ProcessManager: ObservableObject {
    // MARK: Properties
    
    @Published var processes: [ProcessInfo] = []
    
    // MARK: Public Methods
    
    func refreshProcesses() {
        // Implementation
    }
    
    // MARK: Private Methods
    
    private func fetchProcesses() -> [ProcessInfo] {
        // Implementation
    }
}
```

## Testing

### Manual Testing

Before submitting changes:

1. **Build successfully**: Ensure no compilation errors
2. **Run the app**: Test basic functionality
3. **Test your changes**: Verify your feature/fix works
4. **Test edge cases**: Try unusual inputs or scenarios
5. **Check memory leaks**: Use Instruments if adding complex features

### Test Checklist

- [ ] App launches without crashes
- [ ] Menu bar icon appears
- [ ] Process list loads correctly
- [ ] Search functionality works
- [ ] Refresh updates the list
- [ ] Force quit terminates processes
- [ ] Purge button prompts for password
- [ ] No console errors or warnings

## Submitting Changes

### Commit Messages

Write clear, descriptive commit messages:

```
Short summary (50 chars or less)

More detailed explanation if needed. Wrap at 72 characters.
Explain what changes you made and why.

- Bullet points are okay
- Use present tense: "Add feature" not "Added feature"
- Reference issues: "Fixes #123" or "Relates to #456"
```

Examples:
```
Add CPU usage monitoring to process list

- Add CPU percentage to ProcessInfo model
- Update ProcessManager to fetch CPU data
- Display CPU usage in ProcessRow
- Update documentation

Fixes #42
```

### Pull Request Process

1. **Update documentation** if needed
2. **Test thoroughly** on your machine
3. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```
4. **Create a Pull Request** on GitHub
5. **Fill out the PR template** completely
6. **Respond to feedback** from reviewers

### Pull Request Checklist

- [ ] Code builds without errors or warnings
- [ ] Tested on macOS (specify version)
- [ ] Updated README.md if needed
- [ ] Updated CHANGELOG.md
- [ ] No debug code or commented code left in
- [ ] Code follows the style guide
- [ ] Commit messages are clear and descriptive

## Reporting Bugs

### Before Submitting

1. **Check existing issues** to avoid duplicates
2. **Update to latest version** and test again
3. **Gather information** about the bug

### Bug Report Template

```markdown
**Description**
A clear description of the bug.

**To Reproduce**
Steps to reproduce:
1. Open the app
2. Click on '...'
3. See error

**Expected Behavior**
What you expected to happen.

**Actual Behavior**
What actually happened.

**Screenshots**
If applicable, add screenshots.

**Environment**
- macOS Version: [e.g., 14.0]
- Craig-O-Clean Version: [e.g., 1.0.0]
- Mac Model: [e.g., MacBook Pro M1 2021]

**Additional Context**
Any other relevant information.
```

## Requesting Features

### Feature Request Template

```markdown
**Problem Statement**
Describe the problem this feature would solve.

**Proposed Solution**
How you envision this feature working.

**Alternatives Considered**
Other ways you've thought about solving this.

**Additional Context**
Mockups, examples, or related features.
```

## Areas for Contribution

We especially welcome contributions in these areas:

### High Priority
- CPU usage monitoring
- Unit tests for core functionality
- Memory leak detection and fixes
- Performance optimizations
- Accessibility improvements

### Medium Priority
- User preferences/settings
- Configurable refresh intervals
- Export functionality
- Additional memory statistics
- Keyboard shortcuts

### Documentation
- Code documentation
- Usage tutorials
- Video guides
- Translations (future)

### Design
- App icon design
- UI/UX improvements
- Dark mode refinements
- Animations and transitions

## Questions?

- **General questions**: Open a GitHub Discussion
- **Bug reports**: Open a GitHub Issue
- **Feature ideas**: Open a GitHub Issue with the feature label
- **Security issues**: Contact maintainers directly (don't open public issues)

## Recognition

Contributors will be:
- Listed in the README.md
- Credited in release notes
- Thanked in commit messages

Thank you for contributing to Craig-O-Clean! 🎉
