import Foundation

public enum JSONValue: Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    fileprivate var anyValue: Any {
        switch self {
        case let .string(value):
            return value
        case let .number(value):
            return value
        case let .bool(value):
            return value
        case let .object(values):
            return values.mapValues { $0.anyValue }
        case let .array(values):
            return values.map { $0.anyValue }
        case .null:
            return NSNull()
        }
    }

    fileprivate static func fromAny(_ value: Any) -> JSONValue? {
        switch value {
        case let value as String:
            return .string(value)
        case let value as Bool:
            return .bool(value)
        case let value as Int:
            return .number(Double(value))
        case let value as Double:
            return .number(value)
        case let value as Float:
            return .number(Double(value))
        case let value as NSNumber:
            if CFGetTypeID(value) == CFBooleanGetTypeID() {
                return .bool(value.boolValue)
            }
            return .number(value.doubleValue)
        case let value as [Any]:
            var output: [JSONValue] = []
            output.reserveCapacity(value.count)
            for item in value {
                guard let converted = JSONValue.fromAny(item) else {
                    return nil
                }
                output.append(converted)
            }
            return .array(output)
        case let value as [String: Any]:
            return JSONValue.object(from: value)
        case let value as [AnyHashable: Any]:
            return JSONValue.object(from: value)
        case is NSNull:
            return .null
        default:
            return nil
        }
    }

    private static func object(from value: [AnyHashable: Any]) -> JSONValue? {
        var output: [String: JSONValue] = [:]
        output.reserveCapacity(value.count)
        for (key, rawValue) in value {
            guard let key = key as? String,
                  let converted = JSONValue.fromAny(rawValue) else {
                return nil
            }
            output[key] = converted
        }
        return .object(output)
    }
}

public struct JSBeautifyOptions: Sendable, Equatable {
    public var values: [String: JSONValue]

    public init(_ values: [String: JSONValue] = [:]) {
        self.values = values
    }

    public subscript(key: String) -> JSONValue? {
        get { values[key] }
        set { values[key] = newValue }
    }

    public func toDictionary() -> [String: Any] {
        values.mapValues { $0.anyValue }
    }

    public static func from(dictionary: [String: Any]) -> JSBeautifyOptions {
        var output: [String: JSONValue] = [:]
        output.reserveCapacity(dictionary.count)
        for (key, rawValue) in dictionary {
            if let converted = JSONValue.fromAny(rawValue) {
                output[key] = converted
            }
        }
        return JSBeautifyOptions(output)
    }
}

private enum OptionValidation {
    static func clamp(_ value: Int, min: Int, max: Int, name: String) -> Int {
        precondition(min <= max, "Invalid clamp range for \(name).")
        if value < min { return min }
        if value > max { return max }
        return value
    }

    static func nonNegative(_ value: Int, name: String) -> Int {
        precondition(value != Int.min, "\(name) is out of range.")
        return clamp(value, min: 0, max: Int.max, name: name)
    }
}

public struct JSBeautifyFormattingOptions: Sendable, Equatable {
    public enum HTMLTemplating: Sendable, Equatable {
        case auto
        case none
        case engines([HTMLTemplatingEngine])
    }

    public enum HTMLTemplatingEngine: String, Sendable, Equatable {
        case django
        case erb
        case handlebars
        case php
        case smarty
    }

    public enum Indentation: Sendable, Equatable {
        case tabs
        case spaces(Int)
    }

    public enum NewlinesBetweenTokens: Sendable, Equatable {
        case removeAll
        case allow(Int)
    }

    public enum LineWrap: Sendable, Equatable {
        case wrap(Int)
    }

    public enum BraceStyle: Sendable, Equatable {
        case collapse
        case expand
        case endExpand
        case none
    }

    public enum HTMLScriptIndentation: Sendable, Equatable {
        case keep
        case addOneIndent
        case separate
    }

    public enum HTMLWrapAttributes: Sendable, Equatable {
        case auto
        case force
        case forceAligned
        case forceExpandMultiline
        case alignedMultiple
        case preserve
        case preserveAligned
    }

    public var indentation: Indentation = .spaces(4)
    public var newlinesBetweenTokens: NewlinesBetweenTokens = .allow(5)
    public var lineWrap: LineWrap = .wrap(0)
    public var braceStyle: BraceStyle = .collapse
    public var htmlScriptIndentation: HTMLScriptIndentation = .addOneIndent

    public var endWithNewline: Bool = false
    public var supportE4X: Bool = false
    public var commaFirst: Bool = false
    public var detectPackers: Bool = false
    public var preserveInline: Bool = false
    public var keepArrayIndentation: Bool = false
    public var breakChainedMethods: Bool = false
    public var spaceBeforeConditional: Bool = true
    public var unescapeStrings: Bool = false
    public var jslintHappy: Bool = false
    public var indentHeadAndBody: Bool = false
    public var indentEmptyLines: Bool = false

    public var htmlIndentInnerHtml: Bool = false
    public var htmlIndentHeadInnerHtml: Bool = false
    public var htmlIndentBodyInnerHtml: Bool = false
    public var htmlIndentHandlebars: Bool = true
    public var htmlWrapAttributes: HTMLWrapAttributes = .auto
    public var htmlWrapAttributesMinAttrs: Int = 2
    public var htmlWrapAttributesIndentSize: Int? = nil
    public var htmlExtraLiners: [String] = ["head", "body", "/html"]
    public var htmlInlineElements: [String] = [
        "a", "abbr", "area", "audio", "b", "bdi", "bdo", "br", "button", "canvas", "cite",
        "code", "data", "datalist", "del", "dfn", "em", "embed", "i", "iframe", "img", "input",
        "ins", "kbd", "keygen", "label", "map", "mark", "math", "meter", "noscript", "object",
        "output", "progress", "q", "ruby", "s", "samp", "select", "small", "span", "strong",
        "sub", "sup", "svg", "template", "textarea", "time", "u", "var", "video", "wbr", "text",
        "acronym", "big", "strike", "tt"
    ]
    public var htmlInlineCustomElements: Bool = true
    public var htmlVoidElements: [String] = [
        "area", "base", "br", "col", "embed", "hr", "img", "input", "keygen", "link", "menuitem",
        "meta", "param", "source", "track", "wbr", "!doctype", "?xml", "basefont", "isindex"
    ]
    public var htmlUnformatted: [String] = []
    public var htmlContentUnformatted: [String] = ["pre", "textarea"]
    public var htmlUnformattedContentDelimiter: String? = nil
    public var htmlTemplating: HTMLTemplating = .auto

    public var additional: JSBeautifyOptions = JSBeautifyOptions()

    public init() {}

    public func toOptions() -> JSBeautifyOptions {
        JSBeautifyOptions.from(dictionary: toDictionary())
    }

    public func toDictionary() -> [String: Any] {
        var output: [String: Any] = [:]
        var indentSize = 4

        switch indentation {
        case .tabs:
            output["indent_with_tabs"] = true
            output["indent_char"] = "\t"
            indentSize = 4
            output["indent_size"] = indentSize
        case let .spaces(size):
            output["indent_with_tabs"] = false
            output["indent_char"] = " "
            indentSize = OptionValidation.nonNegative(size, name: "indent_size")
            output["indent_size"] = indentSize
        }

        switch newlinesBetweenTokens {
        case .removeAll:
            output["preserve_newlines"] = false
            output["max_preserve_newlines"] = 0
        case let .allow(maxNewlines):
            output["preserve_newlines"] = true
            output["max_preserve_newlines"] = OptionValidation.nonNegative(
                maxNewlines,
                name: "max_preserve_newlines"
            )
        }

        switch lineWrap {
        case let .wrap(length):
            output["wrap_line_length"] = OptionValidation.nonNegative(
                length,
                name: "wrap_line_length"
            )
        }

        switch braceStyle {
        case .collapse:
            output["brace_style"] = "collapse"
        case .expand:
            output["brace_style"] = "expand"
        case .endExpand:
            output["brace_style"] = "end-expand"
        case .none:
            output["brace_style"] = "none"
        }

        switch htmlScriptIndentation {
        case .keep:
            output["indent_scripts"] = "keep"
        case .addOneIndent:
            output["indent_scripts"] = "normal"
        case .separate:
            output["indent_scripts"] = "separate"
        }

        output["end_with_newline"] = endWithNewline
        output["e4x"] = supportE4X
        output["comma_first"] = commaFirst
        output["detect_packers"] = detectPackers
        output["preserve_inline"] = preserveInline
        output["keep_array_indentation"] = keepArrayIndentation
        output["break_chained_methods"] = breakChainedMethods
        output["space_before_conditional"] = spaceBeforeConditional
        output["unescape_strings"] = unescapeStrings
        output["jslint_happy"] = jslintHappy
        output["indent_empty_lines"] = indentEmptyLines

        output["indent_inner_html"] = htmlIndentInnerHtml
        if indentHeadAndBody {
            output["indent_head_inner_html"] = true
            output["indent_body_inner_html"] = true
        } else {
            output["indent_head_inner_html"] = htmlIndentHeadInnerHtml
            output["indent_body_inner_html"] = htmlIndentBodyInnerHtml
        }
        output["indent_handlebars"] = htmlIndentHandlebars

        switch htmlWrapAttributes {
        case .auto:
            output["wrap_attributes"] = "auto"
        case .force:
            output["wrap_attributes"] = "force"
        case .forceAligned:
            output["wrap_attributes"] = "force-aligned"
        case .forceExpandMultiline:
            output["wrap_attributes"] = "force-expand-multiline"
        case .alignedMultiple:
            output["wrap_attributes"] = "aligned-multiple"
        case .preserve:
            output["wrap_attributes"] = "preserve"
        case .preserveAligned:
            output["wrap_attributes"] = "preserve-aligned"
        }
        output["wrap_attributes_min_attrs"] = OptionValidation.nonNegative(
            htmlWrapAttributesMinAttrs,
            name: "wrap_attributes_min_attrs"
        )
        output["wrap_attributes_indent_size"] = OptionValidation.nonNegative(
            htmlWrapAttributesIndentSize ?? indentSize,
            name: "wrap_attributes_indent_size"
        )

        output["extra_liners"] = htmlExtraLiners
        output["inline"] = htmlInlineElements
        output["inline_custom_elements"] = htmlInlineCustomElements
        output["void_elements"] = htmlVoidElements
        output["unformatted"] = htmlUnformatted
        output["content_unformatted"] = htmlContentUnformatted
        if let delimiter = htmlUnformattedContentDelimiter {
            output["unformatted_content_delimiter"] = delimiter
        }

        switch htmlTemplating {
        case .auto:
            output["templating"] = ["auto"]
        case .none:
            output["templating"] = ["none"]
        case let .engines(engines):
            output["templating"] = engines.map { $0.rawValue }
        }

        if !additional.values.isEmpty {
            for (key, value) in additional.values {
                output[key] = value.anyValue
            }
        }

        return output
    }
}
