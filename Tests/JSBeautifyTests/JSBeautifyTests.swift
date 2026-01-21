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
