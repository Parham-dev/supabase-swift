# macOS Development Environment Setup for SwiftSupabaseSync

This guide outlines the complete macOS environment setup for developing and testing SwiftSupabaseSync using Swift's new testing framework.

## Prerequisites

### System Requirements
- **macOS 14.0+** (Sonoma or later)
- **Xcode 15.0+** with Swift 6.0+ support
- **Command Line Tools** for Xcode
- **Git** for version control

### Environment Setup

#### 1. Install Xcode and Developer Tools

```bash
# Install Xcode from App Store or Developer Portal
# Then install command line tools
xcode-select --install

# Verify installation
swift --version
# Should show Swift 6.0+ for new testing framework support
```

#### 2. Configure Swift Package Manager

```bash
# Verify SPM is working
swift package --version

# Clean any existing builds
swift package clean
swift package reset
```

#### 3. Project Setup

```bash
# Clone the repository
git clone https://github.com/Parham-dev/supabase-swift.git
cd supabase-swift

# Verify package configuration
swift package describe

# Build the project
swift build

# Run tests
swift test
```

## Development Environment Configuration

### Xcode Project Setup

1. **Open Package in Xcode**:
   ```bash
   open Package.swift
   # or
   xed .
   ```

2. **Configure Scheme for Testing**:
   - Select the SwiftSupabaseSync scheme
   - Choose "Edit Scheme..."
   - Under "Test", ensure all test targets are enabled
   - Set "Options" -> "Language" to Swift
   - Enable "Code Coverage" for test coverage reports

3. **Swift Testing Framework Setup**:
   - The project uses Swift Testing (not XCTest) for new tests
   - Tests use `@Test` attributes instead of XCTest methods
   - Modern async/await patterns are supported

### Environment Variables

Set up the following environment variables for development:

```bash
# Add to ~/.zshrc or ~/.bash_profile
export SWIFT_TESTING_ENABLED=1
export SUPABASE_URL="your-supabase-url"
export SUPABASE_ANON_KEY="your-supabase-anon-key"
```

### IDE Configuration

#### Xcode Settings
1. **Preferences** → **Text Editing** → **Indentation**:
   - Tab width: 4
   - Indent width: 4
   - Use spaces instead of tabs

2. **Preferences** → **Source Control**:
   - Enable "Show source control changes"
   - Configure Git author information

3. **Preferences** → **Behaviors** → **Testing**:
   - Show navigator: Test navigator
   - Show debugger: Variables & Console View

#### VS Code Alternative Setup
If using VS Code with Swift extension:

```json
{
    "swift.path": "/usr/bin/swift",
    "swift.sourcekit-lsp.serverPath": "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/sourcekit-lsp",
    "swift.testing.enabled": true
}
```

## Testing Framework Configuration

### Swift Testing (New Framework)

The project uses Swift's new testing framework introduced in Swift 6.0:

```swift
import Testing
@testable import SwiftSupabaseSync

struct MyTests {
    @Test("Description of test")
    func testSomething() async throws {
        #expect(true)
    }
    
    @Test("Parameterized test", arguments: [1, 2, 3])
    func testWithParameters(value: Int) async throws {
        #expect(value > 0)
    }
}
```

### Running Tests

#### Command Line
```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter SyncableTests

# Run with verbose output
swift test --verbose

# Run with parallel execution
swift test --parallel

# Generate test coverage
swift test --enable-code-coverage
```

#### Xcode
- **⌘+U**: Run all tests
- **⌘+⌃+U**: Run tests for current file
- **Right-click** test method → "Run test"

### Continuous Integration

#### GitHub Actions Configuration

Create `.github/workflows/tests.yml`:

```yaml
name: Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: macos-14
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Xcode
      uses: maxim-lobanov/setup-xcode@v1
      with:
        xcode-version: '15.0'
    
    - name: Cache SPM
      uses: actions/cache@v3
      with:
        path: .build
        key: ${{ runner.os }}-spm-${{ hashFiles('Package.swift') }}
        restore-keys: |
          ${{ runner.os }}-spm-
    
    - name: Build
      run: swift build
    
    - name: Run tests
      run: swift test --enable-code-coverage
    
    - name: Upload coverage
      uses: codecov/codecov-action@v3
```

## Performance and Debugging

### Instruments Integration

1. **Memory Testing**:
   - Profile → Instruments → Leaks
   - Run sync operations and check for memory leaks

2. **Performance Testing**:
   - Profile → Instruments → Time Profiler
   - Measure sync performance and identify bottlenecks

### Debugging Configuration

```swift
// Debug build configuration
#if DEBUG
extension SwiftSupabaseSync {
    static let isDebugMode = true
    static let logLevel: LogLevel = .debug
}
#endif
```

## Database Setup for Testing

### Local Supabase Development

1. **Install Supabase CLI**:
   ```bash
   npm install -g supabase
   ```

2. **Initialize Local Project**:
   ```bash
   supabase init
   supabase start
   ```

3. **Configure Test Database**:
   ```bash
   # Create test tables
   supabase migration new create_test_tables
   ```

### Test Data Management

```swift
// Test configuration
extension SwiftSupabaseSync {
    static func configureForTesting() {
        configure(
            supabaseURL: "http://localhost:54321",
            supabaseKey: "test-anon-key",
            options: .testing
        )
    }
}
```

## IDE Shortcuts and Productivity

### Essential Xcode Shortcuts
- **⌘+Shift+K**: Clean build folder
- **⌘+B**: Build
- **⌘+R**: Run
- **⌘+U**: Test
- **⌘+Shift+O**: Quick Open
- **⌘+Shift+J**: Reveal in navigator
- **⌘+⌥+/**: Documentation quick help

### Code Navigation
- **⌘+Click**: Jump to definition
- **⌘+⌃+↑**: Switch between header/implementation
- **⌘+⌃+E**: Edit all in scope
- **⌘+F**: Find in file
- **⌘+Shift+F**: Find in project

## Quality Assurance

### Code Coverage Targets
- **Tier 1 (Critical)**: 95%+ coverage
- **Tier 2 (Important)**: 85%+ coverage
- **Tier 3 (Supporting)**: 70%+ coverage

### Static Analysis
Enable in Xcode:
- **Analyze** → **Analyze** (⌘+Shift+B)
- Address all warnings and analyzer issues

### SwiftLint Integration (Optional)

```bash
# Install SwiftLint
brew install swiftlint

# Add to build phases in Xcode
if which swiftlint >/dev/null; then
  swiftlint
else
  echo "warning: SwiftLint not installed"
fi
```

## Troubleshooting

### Common Issues

1. **Build Failures**:
   ```bash
   swift package clean
   swift package reset
   rm -rf .build
   ```

2. **Test Discovery Issues**:
   - Ensure test files are in Tests directory
   - Verify Package.swift test target configuration
   - Check import statements in test files

3. **Dependency Resolution**:
   ```bash
   swift package resolve
   swift package update
   ```

### Performance Optimization

1. **Build Time**:
   - Use `swift build --configuration release` for benchmarks
   - Enable "Whole Module Optimization" in Release builds

2. **Test Execution**:
   - Use `--parallel` flag for faster test execution
   - Consider test grouping for large test suites

This environment setup ensures optimal development experience with Swift's modern testing framework and comprehensive tooling for the SwiftSupabaseSync project.