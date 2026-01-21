# JSBeautify

Swift wrapper around the JavaScript `js-beautify` minifiers (1.14.9) using JavaScriptCore.

## Usage

```swift
import JSBeautify

guard let beautifier = JSBeautify() else {
    fatalError("Failed to initialize JSBeautify")
}

let js = beautifier.beautifyJavaScript("function test(){console.log(\"hi\");}")
let css = beautifier.beautifyCSS("body{color:red;}")
let html = beautifier.beautifyHTML("<div><p>Hello</p><p>World</p></div>")

var format = JSBeautifyFormattingOptions()
format.indentation = .spaces2
let compact = beautifier.beautifyJavaScript(
    "function test(){console.log(\"hi\");}",
    options: format
)
```

Sendable-friendly usage with an actor:

```swift
import JSBeautify

guard let beautifier = JSBeautifyActor() else {
    fatalError("Failed to initialize JSBeautifyActor")
}

var options = JSBeautifyFormattingOptions()
options.indentation = .spaces2
let js = await beautifier.beautifyJavaScript(
    "function test(){console.log(\"hi\");}",
    options: options
)
```

## API

- `JSBeautify()` failable initializer loads the bundled JavaScript files.
- `JSBeautifyActor()` provides Sendable, actor-isolated access for concurrency.
- `beautifyJavaScript(_:options:)`, `beautifyCSS(_:options:)`, `beautifyHTML(_:options:)` return the formatted string or `nil`.
- `defaultJavaScriptOptions()`, `defaultCSSOptions()`, `defaultHTMLOptions()` return the library defaults.
- `availableResources(ofType:)` returns bundled resource names.
- `JSBeautifyFormattingOptions` models the documented presets with strong types.
- `JSBeautifyOptions` and `JSONValue` are Sendable helpers for additional JSON options.

For additional settings not modeled in `JSBeautifyFormattingOptions`, set `format.additional` using JSON-safe values.

## Thread Safety

`JSContext` is not thread-safe. Use a new `JSBeautify` instance per thread or serialize access with a dedicated queue.

## License

The bundled JavaScript library license is copied to `Sources/JSBeautify/Assets/JSBeautify-LICENSE`.
