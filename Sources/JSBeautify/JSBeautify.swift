import Foundation
import JavaScriptCore

public final class JSBeautify {
    public typealias Options = [String: Any]

    private let context: JSContext
    private let jsBeautify: JSValue
    private let cssBeautify: JSValue
    private let htmlBeautify: JSValue
    private let bundle: Bundle

    public init?() {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: JSBeautify.self)
        #endif

        guard let context = JSContext() else {
            return nil
        }

        context.exceptionHandler = { _, exception in
            #if DEBUG
            if let message = exception?.toString() {
                print("[JSBeautify] JavaScript error: \(message)")
            }
            #endif
        }

        context.evaluateScript("var window = this; var self = this; var global = this;")

        #if DEBUG
        let consoleLog: @convention(block) (String) -> Void = { message in
            print("[JSBeautify][JS] \(message)")
        }
        context.setObject(consoleLog, forKeyedSubscript: "swiftLog" as NSString)
        context.evaluateScript(
            """
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
            """
        )
        #endif

        guard let jsSource = Self.loadScript(named: "beautify.min", bundle: bundle),
              let cssSource = Self.loadScript(named: "beautify-css.min", bundle: bundle),
              let htmlSource = Self.loadScript(named: "beautify-html.min", bundle: bundle) else {
            return nil
        }

        context.evaluateScript(jsSource)
        context.evaluateScript(cssSource)
        context.evaluateScript(htmlSource)

        guard let jsBeautify = context.globalObject.objectForKeyedSubscript("js_beautify"),
              !jsBeautify.isUndefined else {
            return nil
        }

        guard let cssBeautify = context.globalObject.objectForKeyedSubscript("css_beautify"),
              !cssBeautify.isUndefined else {
            return nil
        }

        guard let htmlBeautify = context.globalObject.objectForKeyedSubscript("html_beautify"),
              !htmlBeautify.isUndefined else {
            return nil
        }

        self.context = context
        self.jsBeautify = jsBeautify
        self.cssBeautify = cssBeautify
        self.htmlBeautify = htmlBeautify
        self.bundle = bundle
    }

    public func beautifyJavaScript(_ input: String, options: Options = [:]) -> String? {
        return call(function: jsBeautify, input: input, options: options)
    }

    public func beautifyJavaScript(_ input: String, options: JSBeautifyOptions) -> String? {
        return beautifyJavaScript(input, options: options.toDictionary())
    }

    public func beautifyJavaScript(_ input: String, options: JSBeautifyFormattingOptions) -> String? {
        return beautifyJavaScript(input, options: options.toDictionary())
    }

    public func beautifyCSS(_ input: String, options: Options = [:]) -> String? {
        return call(function: cssBeautify, input: input, options: options)
    }

    public func beautifyCSS(_ input: String, options: JSBeautifyOptions) -> String? {
        return beautifyCSS(input, options: options.toDictionary())
    }

    public func beautifyCSS(_ input: String, options: JSBeautifyFormattingOptions) -> String? {
        return beautifyCSS(input, options: options.toDictionary())
    }

    public func beautifyHTML(_ input: String, options: Options = [:]) -> String? {
        return call(function: htmlBeautify, input: input, options: options)
    }

    public func beautifyHTML(_ input: String, options: JSBeautifyOptions) -> String? {
        return beautifyHTML(input, options: options.toDictionary())
    }

    public func beautifyHTML(_ input: String, options: JSBeautifyFormattingOptions) -> String? {
        return beautifyHTML(input, options: options.toDictionary())
    }

    public func defaultJavaScriptOptions() -> Options? {
        return defaultOptions(for: jsBeautify)
    }

    public func defaultCSSOptions() -> Options? {
        return defaultOptions(for: cssBeautify)
    }

    public func defaultHTMLOptions() -> Options? {
        return defaultOptions(for: htmlBeautify)
    }

    public func availableResources(ofType type: String) -> [String] {
        let paths = bundle.paths(forResourcesOfType: type, inDirectory: nil) as [NSString]
        return paths.map { $0.lastPathComponent.replacingOccurrences(of: ".\(type)", with: "") }
    }

    private static func loadScript(named name: String, bundle: Bundle) -> String? {
        guard let path = bundle.path(forResource: name, ofType: "js") else {
            return nil
        }
        return try? String(contentsOfFile: path, encoding: .utf8)
    }

    private func call(function: JSValue, input: String, options: Options) -> String? {
        let result: JSValue?
        if options.isEmpty {
            result = function.call(withArguments: [input])
        } else {
            result = function.call(withArguments: [input, options])
        }
        return Self.stringValue(from: result)
    }

    private func defaultOptions(for function: JSValue) -> Options? {
        guard let defaultOptions = function.objectForKeyedSubscript("defaultOptions"),
              !defaultOptions.isUndefined else {
            return nil
        }
        let result = defaultOptions.call(withArguments: [])
        guard let rawOptions = result?.toDictionary() as? [AnyHashable: Any] else {
            return nil
        }
        var options: Options = [:]
        for (key, value) in rawOptions {
            guard let key = key as? String else {
                continue
            }
            options[key] = value
        }
        return options
    }

    private static func stringValue(from value: JSValue?) -> String? {
        guard let value = value else {
            return nil
        }

        if value.isUndefined || value.isNull {
            return nil
        }

        let stringValue = value.toString()
        if stringValue == "undefined" {
            return nil
        }

        return stringValue
    }
}
