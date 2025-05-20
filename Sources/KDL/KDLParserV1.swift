public class KDLParserV1 : KDLParser {
    public override init(outputVersion: UInt? = nil) {
        super.init(outputVersion: outputVersion ?? 1)
    }

    public override func parse(
        _ string: String,
        parseTypes: Bool = true
    ) throws -> KDLDocument {
        self.tokenizer = KDLTokenizerV1(string)
        return try _document()
    }

}
