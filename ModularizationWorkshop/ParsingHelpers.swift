import Foundation
import Parsing

struct DeepLinkRequest {

    var pathComponents: ArraySlice<Substring>
    var queryItems: [String: ArraySlice<Substring?>]

}

extension DeepLinkRequest {

    init(url: URL) {
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        self.init(
            pathComponents: url.path.split(separator: "/")[...],
            queryItems: queryItems.reduce(into: [:]) { dictionary, item in
                dictionary[item.name, default: []].append(item.value?[...])
            }
        )
    }

}

struct PathComponent<ComponentParser>: Parser where ComponentParser: Parser, ComponentParser.Input == Substring {

    let component: ComponentParser

    init(_ component: ComponentParser) {
        self.component = component
    }

    func parse(_ input: inout DeepLinkRequest) -> ComponentParser.Output? {
        guard var firstComponent = input.pathComponents.first,
              let output = try? self.component.parse(&firstComponent),
              firstComponent.isEmpty else { return nil }

        input.pathComponents.removeFirst()

        return output
    }

}

struct PathEnd: Parser {

    init() {}

    func parse(_ input: inout DeepLinkRequest) -> Void? {
        guard input.pathComponents.isEmpty else { return nil }

        return ()
    }

}

struct QueryItem<ValueParser>: Parser where ValueParser: Parser, ValueParser.Input == Substring {

    let name: String
    let valueParser: ValueParser

    init(_ name: String, _ valueParser: ValueParser) {
        self.name = name
        self.valueParser = valueParser
    }

    init(_ name: String) where ValueParser == Rest<Substring> {
        self.init(name, Rest())
    }

    func parse(_ input: inout DeepLinkRequest) -> ValueParser.Output? {
        guard let wrapped = input.queryItems[self.name]?.first,
              var value = wrapped,
              let output = try? self.valueParser.parse(&value),
              value.isEmpty else { return nil }

        input.queryItems[self.name]?.removeFirst()

        return output
    }
    
}
