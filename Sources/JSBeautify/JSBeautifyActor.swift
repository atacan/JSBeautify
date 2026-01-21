public actor JSBeautifyActor {
    private let wrapper: JSBeautify

    public init?() {
        guard let wrapper = JSBeautify() else {
            return nil
        }
        self.wrapper = wrapper
    }

    public func beautifyJavaScript(
        _ input: String,
        options: JSBeautifyOptions = JSBeautifyOptions()
    ) -> String? {
        wrapper.beautifyJavaScript(input, options: options.toDictionary())
    }

    public func beautifyJavaScript(
        _ input: String,
        options: JSBeautifyFormattingOptions
    ) -> String? {
        wrapper.beautifyJavaScript(input, options: options.toDictionary())
    }

    public func beautifyCSS(
        _ input: String,
        options: JSBeautifyOptions = JSBeautifyOptions()
    ) -> String? {
        wrapper.beautifyCSS(input, options: options.toDictionary())
    }

    public func beautifyCSS(
        _ input: String,
        options: JSBeautifyFormattingOptions
    ) -> String? {
        wrapper.beautifyCSS(input, options: options.toDictionary())
    }

    public func beautifyHTML(
        _ input: String,
        options: JSBeautifyOptions = JSBeautifyOptions()
    ) -> String? {
        wrapper.beautifyHTML(input, options: options.toDictionary())
    }

    public func beautifyHTML(
        _ input: String,
        options: JSBeautifyFormattingOptions
    ) -> String? {
        wrapper.beautifyHTML(input, options: options.toDictionary())
    }

    public func defaultJavaScriptOptions() -> JSBeautifyOptions? {
        guard let options = wrapper.defaultJavaScriptOptions() else {
            return nil
        }
        return JSBeautifyOptions.from(dictionary: options)
    }

    public func defaultCSSOptions() -> JSBeautifyOptions? {
        guard let options = wrapper.defaultCSSOptions() else {
            return nil
        }
        return JSBeautifyOptions.from(dictionary: options)
    }

    public func defaultHTMLOptions() -> JSBeautifyOptions? {
        guard let options = wrapper.defaultHTMLOptions() else {
            return nil
        }
        return JSBeautifyOptions.from(dictionary: options)
    }
}
