import XCTest
@testable import JSBeautify

final class JSBeautifyTests: XCTestCase {
    private enum TestError: Error {
        case initializationFailed
        case nodeProcessFailed
    }

    private func optionsDictionary(_ options: JSBeautifyFormattingOptions) -> [String: Any] {
        options.toDictionary()
    }

    private var repositoryRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        return url
    }

    private var assetsURL: URL {
        repositoryRoot.appendingPathComponent("Sources/JSBeautify/Assets", isDirectory: true)
    }

    private var nodeScriptURL: URL {
        repositoryRoot.appendingPathComponent("Tests/JSBeautifyTests/Fixtures/beautify-node.js")
    }

    private func nodeBeautify(
        mode: String,
        input: String,
        options: [String: Any]
    ) throws -> String {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let inputURL = tempDir.appendingPathComponent("input.txt")
        try input.write(to: inputURL, atomically: true, encoding: .utf8)

        let optionsURL = tempDir.appendingPathComponent("options.json")
        let optionsData = try JSONSerialization.data(withJSONObject: options, options: [])
        try optionsData.write(to: optionsURL)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "node",
            nodeScriptURL.path,
            assetsURL.path,
            mode,
            inputURL.path,
            optionsURL.path
        ]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
            XCTFail("Node process failed: \(errorOutput)")
            throw TestError.nodeProcessFailed
        }

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let result = try JSONSerialization.jsonObject(with: outputData, options: [.allowFragments])
        guard let output = result as? String else {
            XCTFail("Node output was not a string")
            throw TestError.nodeProcessFailed
        }
        return output
    }

    private func makeWrapper() throws -> JSBeautify {
        guard let wrapper = JSBeautify() else {
            XCTFail("Failed to initialize JSBeautify")
            throw TestError.initializationFailed
        }
        return wrapper
    }

    func testInit() {
        XCTAssertNotNil(JSBeautify())
    }

    func testBeautifyJavaScriptDefault() throws {
        let wrapper = try makeWrapper()
        let output = wrapper.beautifyJavaScript("function test(){console.log(\"hi\");}")
        let expected = try nodeBeautify(
            mode: "js",
            input: "function test(){console.log(\"hi\");}",
            options: [:]
        )
        XCTAssertEqual(output, expected)
    }

    func testBeautifyJavaScriptOptions() throws {
        let wrapper = try makeWrapper()
        let output = wrapper.beautifyJavaScript(
            "function test(){console.log(\"hi\");}",
            options: ["indent_size": 2]
        )
        let expected = try nodeBeautify(
            mode: "js",
            input: "function test(){console.log(\"hi\");}",
            options: ["indent_size": 2]
        )
        XCTAssertEqual(output, expected)
    }

    func testBeautifyJavaScriptTypedOptions() throws {
        let wrapper = try makeWrapper()
        var options = JSBeautifyFormattingOptions()
        options.indentation = .spaces(2)
        let output = wrapper.beautifyJavaScript(
            "function test(){console.log(\"hi\");}",
            options: options
        )
        let expected = try nodeBeautify(
            mode: "js",
            input: "function test(){console.log(\"hi\");}",
            options: options.toDictionary()
        )
        XCTAssertEqual(output, expected)
    }

    func testActorBeautifyJavaScript() async throws {
        guard let actor = JSBeautifyActor() else {
            XCTFail("Failed to initialize JSBeautifyActor")
            return
        }
        var options = JSBeautifyFormattingOptions()
        options.indentation = .spaces(2)
        let output = await actor.beautifyJavaScript(
            "function test(){console.log(\"hi\");}",
            options: options
        )
        let expected = try nodeBeautify(
            mode: "js",
            input: "function test(){console.log(\"hi\");}",
            options: options.toDictionary()
        )
        XCTAssertEqual(output, expected)
    }

    func testBeautifyCSSDefault() throws {
        let wrapper = try makeWrapper()
        let output = wrapper.beautifyCSS("body{color:red;}")
        let expected = try nodeBeautify(
            mode: "css",
            input: "body{color:red;}",
            options: [:]
        )
        XCTAssertEqual(output, expected)
    }

    func testBeautifyHTMLDefault() throws {
        let wrapper = try makeWrapper()
        let output = wrapper.beautifyHTML("<div><p>Hello</p><p>World</p></div>")
        let expected = try nodeBeautify(
            mode: "html",
            input: "<div><p>Hello</p><p>World</p></div>",
            options: [:]
        )
        XCTAssertEqual(output, expected)
    }

    func testBeautifyHTMLWrapAttributesTypedOptions() throws {
        let wrapper = try makeWrapper()
        var options = JSBeautifyFormattingOptions()
        options.htmlWrapAttributes = .force
        options.htmlWrapAttributesMinAttrs = 1
        let output = wrapper.beautifyHTML("<div class=\"a\" id=\"b\"></div>", options: options)
        let expected = try nodeBeautify(
            mode: "html",
            input: "<div class=\"a\" id=\"b\"></div>",
            options: options.toDictionary()
        )
        XCTAssertEqual(output, expected)
    }

    func testIndentationOptionsMapping() {
        var options = JSBeautifyFormattingOptions()
        options.indentation = .tabs
        var output = optionsDictionary(options)
        XCTAssertEqual(output["indent_with_tabs"] as? Bool, true)
        XCTAssertEqual(output["indent_char"] as? String, "\t")
        XCTAssertEqual(output["indent_size"] as? Int, 4)

        options.indentation = .spaces(3)
        output = optionsDictionary(options)
        XCTAssertEqual(output["indent_with_tabs"] as? Bool, false)
        XCTAssertEqual(output["indent_char"] as? String, " ")
        XCTAssertEqual(output["indent_size"] as? Int, 3)

        options.indentation = .spaces(-2)
        output = optionsDictionary(options)
        XCTAssertEqual(output["indent_size"] as? Int, 0)
    }

    func testNewlinesBetweenTokensMapping() {
        var options = JSBeautifyFormattingOptions()
        options.newlinesBetweenTokens = .removeAll
        var output = optionsDictionary(options)
        XCTAssertEqual(output["preserve_newlines"] as? Bool, false)
        XCTAssertEqual(output["max_preserve_newlines"] as? Int, 0)

        options.newlinesBetweenTokens = .allow(7)
        output = optionsDictionary(options)
        XCTAssertEqual(output["preserve_newlines"] as? Bool, true)
        XCTAssertEqual(output["max_preserve_newlines"] as? Int, 7)

        options.newlinesBetweenTokens = .allow(-4)
        output = optionsDictionary(options)
        XCTAssertEqual(output["max_preserve_newlines"] as? Int, 0)
    }

    func testLineWrapMapping() {
        var options = JSBeautifyFormattingOptions()
        options.lineWrap = .wrap(120)
        var output = optionsDictionary(options)
        XCTAssertEqual(output["wrap_line_length"] as? Int, 120)

        options.lineWrap = .wrap(-1)
        output = optionsDictionary(options)
        XCTAssertEqual(output["wrap_line_length"] as? Int, 0)
    }

    func testBraceStyleMapping() {
        var options = JSBeautifyFormattingOptions()
        options.braceStyle = .collapse
        var output = optionsDictionary(options)
        XCTAssertEqual(output["brace_style"] as? String, "collapse")

        options.braceStyle = .expand
        output = optionsDictionary(options)
        XCTAssertEqual(output["brace_style"] as? String, "expand")

        options.braceStyle = .endExpand
        output = optionsDictionary(options)
        XCTAssertEqual(output["brace_style"] as? String, "end-expand")

        options.braceStyle = .none
        output = optionsDictionary(options)
        XCTAssertEqual(output["brace_style"] as? String, "none")
    }

    func testHTMLScriptIndentationMapping() {
        var options = JSBeautifyFormattingOptions()
        options.htmlScriptIndentation = .keep
        var output = optionsDictionary(options)
        XCTAssertEqual(output["indent_scripts"] as? String, "keep")

        options.htmlScriptIndentation = .addOneIndent
        output = optionsDictionary(options)
        XCTAssertEqual(output["indent_scripts"] as? String, "normal")

        options.htmlScriptIndentation = .separate
        output = optionsDictionary(options)
        XCTAssertEqual(output["indent_scripts"] as? String, "separate")
    }

    func testBooleanOptionsMapping() {
        var options = JSBeautifyFormattingOptions()
        options.endWithNewline = true
        options.supportE4X = true
        options.commaFirst = true
        options.detectPackers = true
        options.preserveInline = true
        options.keepArrayIndentation = true
        options.breakChainedMethods = true
        options.spaceBeforeConditional = false
        options.unescapeStrings = true
        options.jslintHappy = true
        options.indentHeadAndBody = true
        options.indentEmptyLines = true

        let output = optionsDictionary(options)
        XCTAssertEqual(output["end_with_newline"] as? Bool, true)
        XCTAssertEqual(output["e4x"] as? Bool, true)
        XCTAssertEqual(output["comma_first"] as? Bool, true)
        XCTAssertEqual(output["detect_packers"] as? Bool, true)
        XCTAssertEqual(output["preserve_inline"] as? Bool, true)
        XCTAssertEqual(output["keep_array_indentation"] as? Bool, true)
        XCTAssertEqual(output["break_chained_methods"] as? Bool, true)
        XCTAssertEqual(output["space_before_conditional"] as? Bool, false)
        XCTAssertEqual(output["unescape_strings"] as? Bool, true)
        XCTAssertEqual(output["jslint_happy"] as? Bool, true)
        XCTAssertEqual(output["indent_head_inner_html"] as? Bool, true)
        XCTAssertEqual(output["indent_body_inner_html"] as? Bool, true)
        XCTAssertEqual(output["indent_empty_lines"] as? Bool, true)
    }

    func testHTMLIndentationTogglesMapping() {
        var options = JSBeautifyFormattingOptions()
        options.htmlIndentInnerHtml = true
        options.htmlIndentHeadInnerHtml = true
        options.htmlIndentBodyInnerHtml = true
        options.htmlIndentHandlebars = false

        let output = optionsDictionary(options)
        XCTAssertEqual(output["indent_inner_html"] as? Bool, true)
        XCTAssertEqual(output["indent_head_inner_html"] as? Bool, true)
        XCTAssertEqual(output["indent_body_inner_html"] as? Bool, true)
        XCTAssertEqual(output["indent_handlebars"] as? Bool, false)
    }

    func testHTMLWrapAttributesMapping() {
        var options = JSBeautifyFormattingOptions()
        options.htmlWrapAttributes = .forceAligned
        options.htmlWrapAttributesMinAttrs = -1
        options.htmlWrapAttributesIndentSize = 12

        var output = optionsDictionary(options)
        XCTAssertEqual(output["wrap_attributes"] as? String, "force-aligned")
        XCTAssertEqual(output["wrap_attributes_min_attrs"] as? Int, 0)
        XCTAssertEqual(output["wrap_attributes_indent_size"] as? Int, 12)

        options.htmlWrapAttributesIndentSize = nil
        options.indentation = .spaces(6)
        output = optionsDictionary(options)
        XCTAssertEqual(output["wrap_attributes_indent_size"] as? Int, 6)
    }

    func testHTMLCollectionsMapping() {
        var options = JSBeautifyFormattingOptions()
        options.htmlExtraLiners = ["head", "body"]
        options.htmlInlineElements = ["span", "strong"]
        options.htmlInlineCustomElements = false
        options.htmlVoidElements = ["br", "img"]
        options.htmlUnformatted = ["custom"]
        options.htmlContentUnformatted = ["pre"]
        options.htmlUnformattedContentDelimiter = "---"

        let output = optionsDictionary(options)
        XCTAssertEqual(output["extra_liners"] as? [String], ["head", "body"])
        XCTAssertEqual(output["inline"] as? [String], ["span", "strong"])
        XCTAssertEqual(output["inline_custom_elements"] as? Bool, false)
        XCTAssertEqual(output["void_elements"] as? [String], ["br", "img"])
        XCTAssertEqual(output["unformatted"] as? [String], ["custom"])
        XCTAssertEqual(output["content_unformatted"] as? [String], ["pre"])
        XCTAssertEqual(output["unformatted_content_delimiter"] as? String, "---")
    }

    func testHTMLTemplatingMapping() {
        var options = JSBeautifyFormattingOptions()
        options.htmlTemplating = .auto
        var output = optionsDictionary(options)
        XCTAssertEqual(output["templating"] as? [String], ["auto"])

        options.htmlTemplating = .none
        output = optionsDictionary(options)
        XCTAssertEqual(output["templating"] as? [String], ["none"])

        options.htmlTemplating = .engines([.erb, .handlebars])
        output = optionsDictionary(options)
        XCTAssertEqual(output["templating"] as? [String], ["erb", "handlebars"])
    }

    func testAdditionalOptionsOverrideMapping() {
        var options = JSBeautifyFormattingOptions()
        options.indentation = .spaces(2)
        options.additional = JSBeautifyOptions(["indent_size": .number(10)])

        let output = optionsDictionary(options)
        XCTAssertEqual(output["indent_size"] as? Double, 10)
    }

    func testDefaultOptions() throws {
        let wrapper = try makeWrapper()
        let options = wrapper.defaultJavaScriptOptions()
        let indentSize = (options?["indent_size"] as? NSNumber)?.intValue
        XCTAssertEqual(indentSize, 4)
    }

    func testAvailableResources() throws {
        let wrapper = try makeWrapper()
        let resources = wrapper.availableResources(ofType: "js")
        XCTAssertGreaterThanOrEqual(resources.count, 3)
    }
}
