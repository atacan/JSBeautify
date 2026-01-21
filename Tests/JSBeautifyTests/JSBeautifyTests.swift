import XCTest
@testable import JSBeautify

final class JSBeautifyTests: XCTestCase {
    private enum TestError: Error {
        case initializationFailed
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
        XCTAssertEqual(output, "function test() {\n    console.log(\"hi\");\n}")
    }

    func testBeautifyJavaScriptOptions() throws {
        let wrapper = try makeWrapper()
        let output = wrapper.beautifyJavaScript(
            "function test(){console.log(\"hi\");}",
            options: ["indent_size": 2]
        )
        XCTAssertEqual(output, "function test() {\n  console.log(\"hi\");\n}")
    }

    func testBeautifyJavaScriptTypedOptions() throws {
        let wrapper = try makeWrapper()
        var options = JSBeautifyFormattingOptions()
        options.indentation = .spaces2
        let output = wrapper.beautifyJavaScript(
            "function test(){console.log(\"hi\");}",
            options: options
        )
        XCTAssertEqual(output, "function test() {\n  console.log(\"hi\");\n}")
    }

    func testActorBeautifyJavaScript() async throws {
        guard let actor = JSBeautifyActor() else {
            XCTFail("Failed to initialize JSBeautifyActor")
            return
        }
        var options = JSBeautifyFormattingOptions()
        options.indentation = .spaces2
        let output = await actor.beautifyJavaScript(
            "function test(){console.log(\"hi\");}",
            options: options
        )
        XCTAssertEqual(output, "function test() {\n  console.log(\"hi\");\n}")
    }

    func testBeautifyCSSDefault() throws {
        let wrapper = try makeWrapper()
        let output = wrapper.beautifyCSS("body{color:red;}")
        XCTAssertEqual(output, "body {\n    color: red;\n}")
    }

    func testBeautifyHTMLDefault() throws {
        let wrapper = try makeWrapper()
        let output = wrapper.beautifyHTML("<div><p>Hello</p><p>World</p></div>")
        XCTAssertEqual(output, "<div>\n    <p>Hello</p>\n    <p>World</p>\n</div>")
    }

    func testBeautifyHTMLWrapAttributesTypedOptions() throws {
        let wrapper = try makeWrapper()
        var options = JSBeautifyFormattingOptions()
        options.htmlWrapAttributes = .force
        options.htmlWrapAttributesMinAttrs = 1
        let output = wrapper.beautifyHTML("<div class=\"a\" id=\"b\"></div>", options: options)
        XCTAssertEqual(output, "<div class=\"a\"\n    id=\"b\"></div>")
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
