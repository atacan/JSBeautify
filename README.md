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

let compact = beautifier.beautifyJavaScript(
    "function test(){console.log(\"hi\");}",
    options: ["indent_size": 2]
)
```

## API

- `JSBeautify()` failable initializer loads the bundled JavaScript files.
- `beautifyJavaScript(_:options:)`, `beautifyCSS(_:options:)`, `beautifyHTML(_:options:)` return the formatted string or `nil`.
- `defaultJavaScriptOptions()`, `defaultCSSOptions()`, `defaultHTMLOptions()` return the library defaults.
- `availableResources(ofType:)` returns bundled resource names.

Options must be JSON-safe types (`String`, `Bool`, `Int`, `Double`, `[Any]`, `[String: Any]`, `nil`).

## Thread Safety

`JSContext` is not thread-safe. Use a new `JSBeautify` instance per thread or serialize access with a dedicated queue.

## License

The bundled JavaScript library license is copied to `Sources/JSBeautify/Assets/JSBeautify-LICENSE`.
