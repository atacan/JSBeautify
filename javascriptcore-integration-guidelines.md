# Standard Operating Procedure: Wrapping JavaScript Libraries in Swift

This document is the definitive guide for wrapping JavaScript libraries within Swift packages using JavaScriptCore. It is derived from the analysis of `HighlighterSwift`, which wraps the Highlight.js library.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [JavaScript Preparation](#2-javascript-preparation)
3. [Step-by-Step Implementation](#3-step-by-step-implementation)
4. [Pattern Reference](#4-pattern-reference)
5. [Error Handling Reference](#5-error-handling-reference)
6. [Testing Guidelines](#6-testing-guidelines)
7. [Concurrency & Thread Safety](#7-concurrency--thread-safety)

---

## 1. Prerequisites

### Required Knowledge

- Swift Package Manager (SPM) fundamentals
- Basic JavaScript understanding (no advanced JS required)
- Familiarity with `NSAttributedString` (if processing rich text output)

### Required Files

| File | Purpose |
|------|---------|
| `Package.swift` | SPM manifest with resource declarations |
| `YourWrapper.swift` | Main Swift wrapper class |
| `Shims.swift` | Cross-platform type aliases |
| `your-library.min.js` | The JavaScript library to wrap |

### Required Imports

```swift
import JavaScriptCore  // For JSContext, JSValue
import Foundation      // For Bundle, String, etc.

// Platform-specific (handled via Shims.swift):
#if os(macOS)
import AppKit          // For NSColor, NSFont
#else
import UIKit           // For UIColor, UIFont
#endif
```

### Supported Platforms

The reference implementation supports:
- macOS 11.0+ (Big Sur)
- iOS 12.0+
- tvOS 12.0+
- visionOS 1.0+

---

## 2. JavaScript Preparation

### 2.1 File Architecture

**Rule**: Use a single, self-contained JavaScript file.

The reference implementation uses a single minified file (`highlight.min.js`). The file must be completely self-contained with no external dependencies, `import`, or `require` statements.

**Acceptable**:
```javascript
// Single file with all logic bundled
var hljs = (function() { /* ... */ })();
```

**Not Acceptable**:
```javascript
import { something } from './other-file.js';  // Will not work
const lib = require('external-lib');          // Will not work
```

### 2.2 Scope & Namespace Requirements

**Rule**: The JavaScript library MUST expose its API via a global variable.

JavaScriptCore accesses JavaScript objects through the global namespace. The library must attach its public API to a global variable.

**Correct Pattern** (used by Highlight.js):
```javascript
// The library assigns itself to a global variable
var hljs = { /* methods and properties */ };

// Or using an IIFE that assigns to global
var hljs = (function() {
    return {
        highlight: function(code, options) { /* ... */ },
        listLanguages: function() { /* ... */ }
    };
})();
```

**Incorrect Patterns** (will NOT work):
```javascript
// ES6 modules - NOT SUPPORTED
export function highlight() { /* ... */ }
export default { highlight };

// CommonJS modules - NOT SUPPORTED
module.exports = { highlight };
exports.highlight = function() { /* ... */ };
```

### 2.3 Entry Point Requirements

**Rule**: There is no special "entry point" function. Swift accesses methods directly on the global object.

After evaluating the JavaScript file, Swift extracts the global object and calls its methods directly:

```swift
// Swift accesses the global object
let hljs = context.globalObject.objectForKeyedSubscript("hljs")

// Swift calls methods on it
hljs.invokeMethod("highlight", withArguments: [code, options])
```

**What you need**: A predictable, documented API on the global object. Know which methods to call and what arguments they expect.

### 2.4 Syntax Constraints

**Allowed JavaScript Features**:
- ES5 syntax (var, function, prototype)
- ES6 features supported by JavaScriptCore (let, const, arrow functions, classes, template literals)
- Immediately Invoked Function Expressions (IIFE)
- Global variable assignment

**Prohibited JavaScript Features**:
- `import` / `export` statements (ES6 modules)
- `require()` / `module.exports` (CommonJS)
- DOM APIs (`document`, `window` unless polyfilled)
- Browser-specific APIs (`fetch`, `XMLHttpRequest`, `localStorage`)
- Node.js APIs (`fs`, `path`, `process`)

### 2.5 Preparing Third-Party Libraries

If using a third-party library:

1. **Use bundled/UMD builds**: Look for files named `library.min.js` or `library.umd.js`
2. **Verify global exposure**: Check that the library creates a global variable
3. **Test in isolation**: Run the JS file in a JavaScriptCore context to verify it works
4. **Include the license**: Place the library's license file alongside the JS file

### 2.6 Directory Structure

Place JavaScript files in a dedicated `Assets` directory within your Sources:

```
Sources/
├── YourModule/
│   ├── YourWrapper.swift
│   └── ... other Swift files
└── Assets/
    ├── your-library.min.js
    ├── LICENCE                    // License for the JS library
    └── (any additional resources)
```

---

## 3. Step-by-Step Implementation

### Step 1: Configure Package.swift

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "YourPackageName",
    platforms: [
        .macOS(.v11),
        .iOS(.v12),
        .tvOS(.v12),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "YourModule",
            targets: ["YourModule"]
        ),
    ],
    targets: [
        .target(
            name: "YourModule",
            dependencies: [],
            resources: [
                // CRITICAL: Use .copy() for JavaScript files
                .copy("Assets/your-library.min.js"),
                // Include the JS library's license file
                .copy("Assets/LICENCE"),
                // Add any other resources (CSS, JSON, etc.)
                .copy("Assets/config.json"),
            ]
        ),
        .testTarget(
            name: "YourModuleTests",
            dependencies: ["YourModule"]
        ),
    ]
)
```

**Key Points**:
- Use `.copy()` (not `.process()`) for JavaScript files to preserve them exactly
- Resources are bundled into `Bundle.module` at runtime
- List each resource file explicitly

### Step 2: Create Cross-Platform Shims

Create `Shims.swift` to abstract platform differences:

```swift
// Shims.swift

#if os(macOS)
import AppKit
public typealias HRColor = NSColor
public typealias HRFont  = NSFont
#else
import UIKit
public typealias HRColor = UIColor
public typealias HRFont  = UIFont
#endif

public typealias AttributedStringKey = NSAttributedString.Key

// OPTIONAL: Only needed if your wrapper works with NSTextStorage (rich text editing).
// Include this only if your use case involves text views or attributed string storage.
// This alias is specific to the HighlighterSwift reference implementation.
#if os(macOS)
public typealias TextStorageEditActions = NSTextStorageEditActions
#else
public typealias TextStorageEditActions = NSTextStorage.EditActions
#endif
```

**Purpose**: Isolate all `#if os()` conditionals to this single file. The rest of your codebase uses the type aliases.

**Note**: The `HRColor` and `HRFont` aliases are universally useful. The `TextStorageEditActions` alias is specific to rich text processing and can be omitted if your wrapper doesn't integrate with `NSTextStorage`.

### Step 3: Create the Main Wrapper Class

```swift
// YourWrapper.swift

import JavaScriptCore
import Foundation

open class YourWrapper {

    // MARK: - Private Properties

    /// The JavaScript global object (e.g., "hljs", "marked", "prism")
    private let jsLibrary: JSValue

    /// Bundle reference for loading resources
    private let bundle: Bundle

    // MARK: - Initialization

    /// Failable initializer - returns nil if JavaScript cannot be loaded
    public init?() {
        // 1. Resolve the bundle (handles both SPM and framework contexts)
        // NOTE: `Bundle.module` is a static property synthesized by Swift Package Manager.
        // It only exists when your code is compiled as part of a Swift Package.
        // If you copy this code into a standard Xcode project (not a package),
        // `Bundle.module` will be undefined - that's why we use the #if check.
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: YourWrapper.self)
        #endif

        // 2. Locate the JavaScript file
        guard let jsPath = bundle.path(forResource: "your-library.min", ofType: "js") else {
            return nil
        }

        // 3. Load JavaScript source code
        guard let jsSource = try? String(contentsOfFile: jsPath, encoding: .utf8) else {
            return nil
        }

        // 4. Create JavaScript context and evaluate the script
        guard let context = JSContext() else {
            return nil
        }
        context.evaluateScript(jsSource)

        // 5. Extract the global object by name
        // IMPORTANT: Replace "yourGlobalName" with your library's actual global variable
        guard let jsLibrary = context.globalObject.objectForKeyedSubscript("yourGlobalName"),
              !jsLibrary.isUndefined else {
            return nil
        }

        // 6. Store references
        self.jsLibrary = jsLibrary
        self.bundle = bundle
    }
}
```

### Step 3.1: Enable JavaScript Debugging (Recommended)

By default, JavaScript `console.log()` calls produce no output in Xcode. To capture JavaScript logs during development, inject a `console` polyfill immediately after creating the context.

Add this code to your initializer, right after `guard let context = JSContext()`:

```swift
// MARK: - Debug Logging Setup (add after JSContext creation)

// Create a Swift function that JavaScript can call
let consoleLog: @convention(block) (String) -> Void = { message in
    print("[JS Log]: \(message)")
}

// Inject the function into the JavaScript global scope
context.setObject(consoleLog, forKeyedSubscript: "swiftLog" as NSString)

// Create a console.log polyfill that calls our Swift function
// Note: JavaScript console.log accepts variadic arguments (e.g., console.log("a", "b", obj))
// The JS wrapper collects all arguments, converts objects to JSON, joins them with spaces,
// and passes the final single string to Swift. Swift only sees the combined result.
context.evaluateScript("""
    var console = {
        log: function() {
            var args = Array.prototype.slice.call(arguments);
            swiftLog(args.map(function(arg) {
                return typeof arg === 'object' ? JSON.stringify(arg) : String(arg);
            }).join(' '));
        },
        warn: function() { console.log('[WARN]', arguments); },
        error: function() { console.log('[ERROR]', arguments); }
    };
    """)
```

**What This Does**:
- Creates a Swift closure that prints to the Xcode console
- Injects it into the JavaScript context as `swiftLog`
- Defines a JavaScript `console` object that routes `log`, `warn`, and `error` calls to Swift
- Handles multiple arguments and object serialization

**Example Output**:
```
[JS Log]: Processing input: hello world
[JS Log]: [WARN] Deprecated function called
[JS Log]: Result: {"status": "success", "count": 42}
```

**Production Consideration**: You may want to conditionally enable this only in DEBUG builds:

```swift
#if DEBUG
// ... console polyfill code ...
#endif
```

**Retain Cycle Warning**: If you move this logging setup into a method that references `self` (e.g., to log to a custom logger instance), remember to capture `self` weakly:

```swift
// If your closure references self (e.g., self.logger.log(message)):
let consoleLog: @convention(block) (String) -> Void = { [weak self] message in
    self?.logger.log("[JS]: \(message)")
}
```

See Section 4.5 for full details on retain cycles with JavaScript callbacks.

### Step 3.2: Add Common Polyfills (If Needed)

Many JavaScript libraries (especially UMD builds) assume the existence of browser globals like `window` or `self`. If a library fails to load with errors about missing globals, add these polyfills immediately after creating the context:

```swift
// Polyfill browser globals that many JS libraries expect
context.evaluateScript("""
    var window = this;
    var self = this;
    var global = this;
    """)
```

**When You Need This**:
- Library throws "window is not defined" or "self is not defined"
- Library was built for browser/Node.js and uses UMD module format
- Library checks `typeof window !== 'undefined'` for environment detection

**When You Don't Need This**:
- Library was specifically built for JavaScriptCore
- Library works correctly without these globals (like Highlight.js)

Add polyfills **before** evaluating the library script:

```swift
guard let context = JSContext() else { return nil }

// 1. Add polyfills first
context.evaluateScript("var window = this; var self = this;")

// 2. Then evaluate the library
context.evaluateScript(jsSource)
```

### Step 4: Implement Method Wrappers

For each JavaScript method you need to call, create a Swift wrapper:

```swift
// Continuing in YourWrapper.swift

extension YourWrapper {

    // MARK: - Public Methods

    /// Example: Wrapping a JavaScript function with one argument
    /// JavaScript: yourLib.process(input) -> { result: string, status: number }
    public func process(_ input: String) -> String? {
        // Call the JavaScript method
        let result = jsLibrary.invokeMethod("process", withArguments: [input])

        // Extract a property from the result object
        guard let resultValue = result?.objectForKeyedSubscript("result"),
              !resultValue.isUndefined else {
            return nil
        }

        // Convert to Swift type
        return resultValue.toString()
    }

    /// Example: Wrapping a function with options dictionary
    /// JavaScript: yourLib.transform(code, { option1: value, option2: value })
    public func transform(_ code: String, option1: Bool, option2: String) -> String? {
        // Build the options dictionary
        let options: [String: Any] = [
            "option1": option1,
            "option2": option2
        ]

        // Call with multiple arguments
        let result = jsLibrary.invokeMethod("transform", withArguments: [code, options])

        // Handle undefined as error
        guard let resultString = result?.toString(),
              resultString != "undefined" else {
            return nil
        }

        return resultString
    }

    /// Example: Wrapping a function that returns an array
    /// JavaScript: yourLib.listItems() -> ["item1", "item2", ...]
    public func listItems() -> [String] {
        guard let result = jsLibrary.invokeMethod("listItems", withArguments: []),
              let array = result.toArray() as? [String] else {
            return []
        }
        return array
    }
}
```

### Step 5: Implement Resource Loading (Optional)

If your wrapper needs to load additional resources (CSS, JSON, etc.):

```swift
extension YourWrapper {

    /// Load a resource file from the bundle
    public func loadResource(named name: String, ofType type: String) -> String? {
        guard let path = bundle.path(forResource: name, ofType: type) else {
            return nil
        }
        return try? String(contentsOfFile: path, encoding: .utf8)
    }

    /// List all resources of a specific type
    public func availableResources(ofType type: String) -> [String] {
        let paths = bundle.paths(forResourcesOfType: type, inDirectory: nil) as [NSString]
        return paths.map { $0.lastPathComponent.replacingOccurrences(of: ".\(type)", with: "") }
    }
}
```

### Step 6: Add Error Handling Wrapper (Optional)

For more robust error handling:

```swift
extension YourWrapper {

    /// Invoke a JS method with comprehensive error handling
    private func safeInvoke(_ methodName: String, arguments: [Any]) -> JSValue? {
        let result = jsLibrary.invokeMethod(methodName, withArguments: arguments)

        // Check for undefined
        if result?.isUndefined == true {
            return nil
        }

        // Check for null
        if result?.isNull == true {
            return nil
        }

        return result
    }
}
```

---

## 4. Pattern Reference

### 4.1 Type Conversion: Swift to JavaScript

When passing Swift values to `invokeMethod(_:withArguments:)`:

| Swift Type | JavaScript Type | Example |
|------------|-----------------|---------|
| `String` | string | `"hello"` → `"hello"` |
| `Int` | number | `42` → `42` |
| `Double` | number | `3.14` → `3.14` |
| `Bool` | boolean | `true` → `true` |
| `Date` | Date | `Date()` → `new Date()` |
| `[Any]` | array | `[1, "a", true]` → `[1, "a", true]` |
| `[String: Any]` | object | `["key": "value"]` → `{key: "value"}` |
| `nil` | null | `nil` → `null` |
| `NSNull()` | null | `NSNull()` → `null` |

> **CRITICAL: JSON-Safe Types Only**
>
> The `Any` type in `[String: Any]` or `[Any]` must be limited to **JSON-compatible primitives**:
> - `String`
> - `Int`, `Double`, `Float` (numbers)
> - `Bool`
> - `[Any]` (nested arrays of primitives)
> - `[String: Any]` (nested dictionaries of primitives)
> - `nil` / `NSNull()`
>
> **Custom Swift Structs and Classes will NOT work.** They will be silently converted to `null` or cause undefined behavior.
>
> **If you need to pass a custom type**, convert it to a Dictionary first:
>
> ```swift
> // WRONG - This will fail silently
> struct User { let name: String; let age: Int }
> let user = User(name: "Alice", age: 30)
> jsLibrary.invokeMethod("process", withArguments: [user])  // user becomes null!
>
> // CORRECT - Convert to Dictionary
> let userDict: [String: Any] = ["name": user.name, "age": user.age]
> jsLibrary.invokeMethod("process", withArguments: [userDict])  // Works!
>
> // ALTERNATIVE - Use Codable for complex types
> let userData = try JSONEncoder().encode(user)
> let userJSON = String(data: userData, encoding: .utf8)!
> jsLibrary.invokeMethod("processJSON", withArguments: [userJSON])
> ```

**Example**:
```swift
// Swift
let options: [String: Any] = [
    "language": "swift",
    "lineNumbers": true,
    "startLine": 1
]
jsLibrary.invokeMethod("process", withArguments: [code, options])

// Equivalent JavaScript
yourLib.process(code, { language: "swift", lineNumbers: true, startLine: 1 })
```

**Performance Note for Large Data**:

For typical use cases (code highlighting, markdown parsing, etc.), `invokeMethod` performance is excellent. However, when passing very large strings (megabytes of data), bridging overhead can become noticeable.

For large data scenarios, setting a global variable can be more performant than passing as an argument:

```swift
// Standard approach (fine for most cases)
jsLibrary.invokeMethod("process", withArguments: [largeString])

// Alternative for very large data (reduces bridging overhead)
// 1. Set the large string as a global variable
context.globalObject.setValue(largeString, forProperty: "inputData")

// 2. evaluateScript returns the result of the last expression directly
let result = context.evaluateScript("yourLib.process(inputData)")

// 3. Convert the result as usual
let outputString = result?.toString()
```

This difference is negligible for libraries like Highlight.js but may matter for data-intensive operations.

### 4.2 Type Conversion: JavaScript to Swift

When extracting values from `JSValue`:

| JavaScript Type | Swift Extraction | Result Type |
|-----------------|------------------|-------------|
| string | `.toString()` | `String?` |
| number | `.toInt32()` | `Int32` |
| number | `.toDouble()` | `Double` |
| boolean | `.toBool()` | `Bool` |
| Date | `.toDate()` | `Date?` |
| Array | `.toArray()` | `[Any]?` |
| Object | `.toDictionary()` | `[AnyHashable: Any]?` |
| property | `.objectForKeyedSubscript("key")` | `JSValue?` |
| array element | `.objectAtIndexedSubscript(0)` | `JSValue?` |

**Example**:
```swift
// JavaScript returns: { value: "result", count: 42, items: ["a", "b"] }

let result = jsLibrary.invokeMethod("getData", withArguments: [])

// Extract string property
let value = result?.objectForKeyedSubscript("value")?.toString()  // "result"

// Extract number property
let count = result?.objectForKeyedSubscript("count")?.toInt32()   // 42

// Extract array property
let items = result?.objectForKeyedSubscript("items")?.toArray() as? [String]  // ["a", "b"]
```

### 4.3 Checking for Undefined/Null

JavaScript functions may return `undefined` or `null`. Always check:

```swift
func safeExtract(_ jsValue: JSValue?) -> String? {
    // Check if JSValue itself is nil
    guard let value = jsValue else {
        return nil
    }

    // Check for JavaScript undefined
    if value.isUndefined {
        return nil
    }

    // Check for JavaScript null
    if value.isNull {
        return nil
    }

    // Check for string "undefined" (some libs return this)
    let str = value.toString()
    if str == "undefined" {
        return nil
    }

    return str
}
```

### 4.4 Passing Nested Objects

For complex nested structures:

```swift
let config: [String: Any] = [
    "theme": [
        "name": "dark",
        "colors": [
            "background": "#000000",
            "foreground": "#ffffff"
        ]
    ],
    "options": [
        "enabled": true,
        "values": [1, 2, 3]
    ]
]

jsLibrary.invokeMethod("configure", withArguments: [config])

// JavaScript receives:
// {
//   theme: { name: "dark", colors: { background: "#000000", foreground: "#ffffff" } },
//   options: { enabled: true, values: [1, 2, 3] }
// }
```

### 4.5 Handling Callbacks (Advanced)

If the JavaScript library uses callbacks, you can pass Swift closures:

```swift
// Define a Swift closure
let callback: @convention(block) (String) -> Void = { result in
    print("Callback received: \(result)")
}

// Create a JSValue from the closure
let context = JSContext()!
let jsCallback = JSValue(object: callback, in: context)

// Pass to JavaScript
jsLibrary.invokeMethod("processAsync", withArguments: [input, jsCallback as Any])
```

> **CRITICAL: Retain Cycle Warning**
>
> When using `@convention(block)` closures that capture `self`, you can easily create memory leaks:
>
> ```
> self → JSContext → JSValue (closure) → self  [RETAIN CYCLE]
> ```
>
> If the closure references `self` (e.g., to update UI or call instance methods), and the `JSContext` is owned by `self`, the wrapper will never deallocate.
>
> **Always capture `self` weakly in callbacks:**
>
> ```swift
> // WRONG - Creates retain cycle if self owns the JSContext
> let callback: @convention(block) (String) -> Void = { result in
>     self.handleResult(result)  // Strong capture of self
> }
>
> // CORRECT - Use [weak self] to break the cycle
> let callback: @convention(block) (String) -> Void = { [weak self] result in
>     guard let self = self else { return }
>     self.handleResult(result)
> }
>
> // ALTERNATIVE - Use [unowned self] if you guarantee self outlives the callback
> let callback: @convention(block) (String) -> Void = { [unowned self] result in
>     self.handleResult(result)
> }
> ```

**Note**: Callbacks add complexity. Prefer synchronous APIs when available.

### 4.6 Bundle Resolution Pattern

Always use this pattern for cross-context bundle resolution:

```swift
#if SWIFT_PACKAGE
let bundle = Bundle.module
#else
let bundle = Bundle(for: YourWrapper.self)
#endif
```

This handles:
- Swift Package Manager builds (`Bundle.module`)
- Framework/CocoaPods builds (`Bundle(for:)`)

---

## 5. Error Handling Reference

### 5.1 Initialization Failures

Use failable initializer (`init?`) for the wrapper:

```swift
public init?() {
    // Each guard returns nil on failure
    guard let jsPath = bundle.path(forResource: "library", ofType: "js") else {
        return nil  // JavaScript file missing
    }

    guard let jsSource = try? String(contentsOfFile: jsPath) else {
        return nil  // Cannot read file
    }

    guard let context = JSContext() else {
        return nil  // Context creation failed
    }

    context.evaluateScript(jsSource)

    guard let lib = context.globalObject.objectForKeyedSubscript("yourLib"),
          !lib.isUndefined else {
        return nil  // Global object not found
    }

    self.jsLibrary = lib
}
```

**Consumer Usage**:
```swift
guard let wrapper = YourWrapper() else {
    // Handle initialization failure
    fatalError("Failed to initialize JavaScript wrapper")
}
```

### 5.2 Method Call Failures

Return optionals for methods that can fail:

```swift
public func process(_ input: String) -> String? {
    let result = jsLibrary.invokeMethod("process", withArguments: [input])

    // Guard against undefined
    guard let resultValue = result?.objectForKeyedSubscript("output"),
          !resultValue.isUndefined else {
        return nil
    }

    let str = resultValue.toString()

    // Guard against "undefined" string
    guard str != "undefined" else {
        return nil
    }

    return str
}
```

### 5.3 Boolean Return for Operations

For operations that succeed or fail, use `@discardableResult`:

```swift
@discardableResult
public func configure(with options: [String: Any]) -> Bool {
    guard let result = jsLibrary.invokeMethod("configure", withArguments: [options]),
          !result.isUndefined else {
        return false
    }
    return true
}
```

**Consumer Usage**:
```swift
// Check result
if wrapper.configure(with: options) {
    // Success
} else {
    // Failure
}

// Or ignore result
wrapper.configure(with: options)
```

### 5.4 Defensive Fallbacks

For non-critical operations, provide sensible defaults:

```swift
public func getColor(for key: String) -> HRColor {
    guard let result = jsLibrary.invokeMethod("getColor", withArguments: [key]),
          let hexString = result.toString(),
          hexString != "undefined",
          let color = parseHexColor(hexString) else {
        return HRColor.gray  // Fallback to neutral color
    }
    return color
}
```

### 5.5 Exception Handling

JavaScriptCore does not throw Swift exceptions for JavaScript errors. Set an exception handler on the context:

```swift
let context = JSContext()!

context.exceptionHandler = { context, exception in
    if let exc = exception {
        print("JavaScript Error: \(exc.toString() ?? "Unknown error")")
    }
}

context.evaluateScript(jsSource)
```

**Important**: The exception handler is informational. Your code should still check return values for validity.

---

## 6. Testing Guidelines

### 6.1 Test Categories

| Category | Purpose | Example |
|----------|---------|---------|
| Initialization | Verify wrapper loads correctly | `testInit()` |
| Valid Input | Verify correct behavior | `testProcessValidInput()` |
| Invalid Input | Verify graceful failure | `testProcessInvalidLanguage()` |
| Edge Cases | Boundary conditions | `testEmptyInput()`, `testLargeInput()` |
| Resource Loading | Verify bundled resources | `testAvailableThemes()` |

### 6.2 Example Test Structure

```swift
import XCTest
@testable import YourModule

final class YourWrapperTests: XCTestCase {

    var wrapper: YourWrapper!

    override func setUp() {
        super.setUp()
        wrapper = YourWrapper()
        XCTAssertNotNil(wrapper, "Wrapper should initialize successfully")
    }

    // MARK: - Initialization Tests

    func testInit() {
        XCTAssertNotNil(YourWrapper())
    }

    // MARK: - Valid Input Tests

    func testProcessValidInput() {
        let result = wrapper.process("valid input")
        XCTAssertNotNil(result)
        XCTAssertFalse(result!.isEmpty)
    }

    // MARK: - Invalid Input Tests

    func testProcessInvalidInput() {
        let result = wrapper.process("", invalidOption: "bad")
        XCTAssertNil(result, "Should return nil for invalid input")
    }

    // MARK: - Edge Cases

    func testEmptyInput() {
        let result = wrapper.process("")
        // Define expected behavior for empty input
        XCTAssertNotNil(result)
    }

    // MARK: - Resource Tests

    func testAvailableResources() {
        let resources = wrapper.availableResources(ofType: "json")
        XCTAssertFalse(resources.isEmpty, "Should have at least one resource")
    }
}
```

### 6.3 Type Conversion Tests

Always test type conversions with edge cases:

```swift
func testColorParsing() {
    // Standard 6-digit hex
    XCTAssertEqual(wrapper.parseColor("#FF0000"), expectedRed)

    // 3-digit shorthand
    XCTAssertEqual(wrapper.parseColor("#F00"), expectedRed)

    // 8-digit with alpha
    XCTAssertEqual(wrapper.parseColor("#FF000080"), expectedRedHalfTransparent)

    // Invalid input - should return fallback
    XCTAssertEqual(wrapper.parseColor("invalid"), fallbackGray)
    XCTAssertEqual(wrapper.parseColor("#GGGGGG"), fallbackGray)
}
```

---

## 7. Concurrency & Thread Safety

### The Problem

**`JSContext` is NOT thread-safe.** If you access the same `JSContext` (or any `JSValue` derived from it) from multiple threads simultaneously, your application will crash or exhibit undefined behavior.

This is a critical consideration because:
- UI code typically runs on the main thread
- Background processing (network callbacks, user-initiated tasks) runs on other threads
- Concurrent access to the wrapper from different threads will cause crashes

### Threading Strategies

You must choose one of the following patterns based on your use case:

#### Pattern 1: Transient Instances (Safest)

Create a new wrapper instance for each operation. Each instance has its own `JSContext`, eliminating thread conflicts.

```swift
// Each call creates a fresh context - thread-safe by isolation
func processInBackground(_ input: String, completion: @escaping (String?) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
        // New instance = new JSContext = no conflicts
        guard let wrapper = YourWrapper() else {
            completion(nil)
            return
        }
        let result = wrapper.process(input)

        DispatchQueue.main.async {
            completion(result)
        }
    }
}
```

**Trade-offs**:
| Pros | Cons |
|------|------|
| Completely thread-safe | Context initialization overhead per call |
| No locking complexity | Higher memory usage (multiple contexts) |
| Simple to reason about | Slower for high-frequency operations |

**Best For**: Infrequent operations, batch processing, cases where simplicity trumps performance.

#### Pattern 2: Shared Instance with Serial Queue (Recommended)

Use a single wrapper instance but serialize all access through a dedicated `DispatchQueue`.

```swift
public class ThreadSafeWrapper {
    private let wrapper: YourWrapper
    private let queue = DispatchQueue(label: "com.yourapp.jswrapper", qos: .userInitiated)

    public init?() {
        // Initialize on current thread (typically main)
        guard let wrapper = YourWrapper() else {
            return nil
        }
        self.wrapper = wrapper
    }

    /// Synchronous processing (blocks until complete)
    public func processSync(_ input: String) -> String? {
        return queue.sync {
            return wrapper.process(input)
        }
    }

    /// Asynchronous processing (returns immediately)
    public func processAsync(_ input: String, completion: @escaping (String?) -> Void) {
        queue.async {
            let result = self.wrapper.process(input)
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
}
```

**Trade-offs**:
| Pros | Cons |
|------|------|
| Single context initialization | All JS calls are serialized (no parallelism) |
| Lower memory usage | Sync calls block the calling thread |
| Predictable performance | Slightly more complex API |

**Best For**: Most applications, especially those with frequent JS calls.

#### Pattern 3: Actor-Based Isolation (Swift 5.5+)

For modern Swift codebases, use an Actor to provide compile-time thread safety:

```swift
@available(macOS 10.15, iOS 13.0, *)
public actor JSWrapperActor {
    private let wrapper: YourWrapper

    public init?() {
        guard let wrapper = YourWrapper() else {
            return nil
        }
        self.wrapper = wrapper
    }

    public func process(_ input: String) -> String? {
        return wrapper.process(input)
    }

    public func listItems() -> [String] {
        return wrapper.listItems()
    }
}

// Usage
Task {
    guard let actor = await JSWrapperActor() else { return }
    let result = await actor.process("hello")
}
```

> **WARNING: JSValue is NOT Sendable - Accessing It Off-Thread WILL Crash**
>
> Never return a `JSValue` from an Actor or pass it across thread boundaries. `JSValue` is permanently bound to the thread/context where it was created.
>
> **This will crash your app:**
> - Returning a `JSValue` from an actor method
> - Storing a `JSValue` and accessing it from another thread
> - Calling `.toString()`, `.toArray()`, or any other method on a `JSValue` from a different thread than where it was created
>
> The conversion to native Swift types **must** happen on the same thread/context where the `JSValue` was created. Even if you somehow get a `JSValue` reference out of the actor, calling any method on it from the caller's thread causes an immediate crash.
>
> ```swift
> // WRONG - Returning JSValue crosses actor boundary
> public func getRawResult(_ input: String) -> JSValue? {
>     return jsLibrary.invokeMethod("process", withArguments: [input])
> }
> // Caller does: let val = await actor.getRawResult("x")
> // val.toString()  // CRASH - accessing JSValue from wrong thread
>
> // CORRECT - Convert to native Swift types INSIDE the actor before returning
> public func getResult(_ input: String) -> String? {
>     let jsValue = jsLibrary.invokeMethod("process", withArguments: [input])
>     return jsValue?.toString()  // Conversion happens here, on the actor's thread
> }
>
> public func getItems() -> [String] {
>     let jsValue = jsLibrary.invokeMethod("listItems", withArguments: [])
>     return jsValue?.toArray() as? [String] ?? []  // [String] is Sendable and safe to return
> }
> ```
>
> **Rule**: All `JSValue` → Swift type conversions must happen inside the actor. Only return `Sendable` types (`String`, `Int`, `Bool`, `[String]`, `[String: Any]`, etc.).

**Trade-offs**:
| Pros | Cons |
|------|------|
| Compile-time safety | Requires Swift 5.5+ / iOS 13+ |
| Clean async/await API | All access becomes async |
| No manual locking | Learning curve for actors |

**Best For**: Modern async/await codebases, new projects targeting iOS 13+.

#### Pattern 4: Lock-Based Protection (Low-Level)

Use `NSLock` for explicit mutual exclusion:

```swift
public class LockedWrapper {
    private let wrapper: YourWrapper
    private let lock = NSLock()

    public init?() {
        guard let wrapper = YourWrapper() else {
            return nil
        }
        self.wrapper = wrapper
    }

    public func process(_ input: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return wrapper.process(input)
    }
}
```

**Trade-offs**:
| Pros | Cons |
|------|------|
| Fine-grained control | Risk of deadlocks if misused |
| Works on all OS versions | Manual lock management |
| Minimal overhead | Easy to forget unlock on error paths |

**Best For**: Performance-critical code, legacy codebases, when DispatchQueue overhead matters.

### Choosing a Strategy

| Scenario | Recommended Pattern |
|----------|---------------------|
| Simple CLI tool, scripts | Pattern 1 (Transient) |
| iOS/macOS app with occasional JS calls | Pattern 2 (Serial Queue) |
| High-frequency calls, modern codebase | Pattern 3 (Actor) |
| Performance-critical, legacy code | Pattern 4 (Lock) |
| Unit tests | Pattern 1 (Transient) - isolation between tests |

### Testing Thread Safety

Add a stress test to verify your threading strategy:

```swift
func testConcurrentAccess() {
    let wrapper = ThreadSafeWrapper()!  // Your thread-safe wrapper
    let expectation = XCTestExpectation(description: "Concurrent processing")
    expectation.expectedFulfillmentCount = 100

    for i in 0..<100 {
        DispatchQueue.global().async {
            let result = wrapper.processSync("input-\(i)")
            XCTAssertNotNil(result)
            expectation.fulfill()
        }
    }

    wait(for: [expectation], timeout: 10.0)
}
```

---

## Appendix A: Complete Minimal Example

Here is a complete minimal implementation for reference:

```swift
// Package.swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MyJSWrapper",
    platforms: [.macOS(.v11), .iOS(.v12)],
    products: [
        .library(name: "MyJSWrapper", targets: ["MyJSWrapper"]),
    ],
    targets: [
        .target(
            name: "MyJSWrapper",
            resources: [.copy("Assets/mylib.min.js")]
        ),
    ]
)
```

```swift
// Sources/MyJSWrapper/MyJSWrapper.swift
import JavaScriptCore
import Foundation

public class MyJSWrapper {
    private let jsLib: JSValue

    public init?() {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: MyJSWrapper.self)
        #endif

        guard let path = bundle.path(forResource: "mylib.min", ofType: "js"),
              let source = try? String(contentsOfFile: path),
              let context = JSContext() else {
            return nil
        }

        context.evaluateScript(source)

        guard let lib = context.globalObject.objectForKeyedSubscript("myLib"),
              !lib.isUndefined else {
            return nil
        }

        self.jsLib = lib
    }

    public func process(_ input: String) -> String? {
        let result = jsLib.invokeMethod("process", withArguments: [input])
        guard let str = result?.toString(), str != "undefined" else {
            return nil
        }
        return str
    }
}
```

```javascript
// Sources/Assets/mylib.min.js
var myLib = {
    process: function(input) {
        return "Processed: " + input;
    }
};
```

---

## Appendix B: Checklist

Before releasing your wrapper:

**JavaScript Setup**
- [ ] JavaScript file is self-contained (no imports/requires)
- [ ] JavaScript library exposes a global variable
- [ ] Package.swift uses `.copy()` for JS files
- [ ] Third-party library license is included

**Swift Implementation**
- [ ] All `#if os()` conditionals are isolated in Shims.swift
- [ ] Failable initializer handles all failure modes
- [ ] All public methods handle undefined/null returns
- [ ] Bundle resolution works for both SPM and framework builds
- [ ] Only JSON-safe types passed to JavaScript (no custom structs/classes)

**Thread Safety**
- [ ] Threading strategy documented and implemented (see Section 7)
- [ ] Wrapper is either transient, queue-protected, or actor-isolated
- [ ] Concurrent access stress test passes

**Debugging**
- [ ] `console.log` polyfill added for development builds
- [ ] Exception handler configured on JSContext

**Testing**
- [ ] Tests cover initialization, valid input, invalid input, and edge cases
- [ ] Type conversion tests include edge cases (empty strings, special characters)
- [ ] Thread safety stress test included

---

*Document Version: 1.3*
*Based on: HighlighterSwift (Highlight.js 11.11.1 wrapper)*
