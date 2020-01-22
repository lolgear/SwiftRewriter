import Foundation
import Curry
import Commandant
import Files
import SwiftSyntax
import SwiftRewriter

public struct RunCommand: CommandProtocol
{
    public typealias Options = RunOptions

    public let verb = "run"
    public let function = "Auto-correct code in the file or directory"

    func run(_ options: Options) throws
    {
        if let file = try? File(path: options.path) {
            if options.outputPath != nil {
                try self._processOutputToFile(file, options: options)
            }
            else {
                try self._processFile(file, options: options)
            }
        }
        else if let folder = try? Folder(path: options.path) {
            try self._processFolder(folder, options: options)
        }
        else {
            print("no input files or directory")
        }
    }
    
    private func _processOutputToFile(_ source: File, options: Options) throws {
        guard source.extension == "swift" else { return }
        guard let outputPath = options.outputPath, let output = try? File(path: outputPath, using: .default) else { throw NSError(domain: "com.arguments", code: -100, userInfo: [NSLocalizedDescriptionKey: "File not exists or path is nil! \(options)"]) }
        let t1 = DispatchTime.now()

        let sourceFile: SourceFileSyntax =
            try Rewriter.parse(sourceFileURL: URL(fileURLWithPath: source.path))

        let t2 = DispatchTime.now()
        
        let result = rewriter.rewrite(sourceFile)

        let t3 = DispatchTime.now()

        print("Processing file: \(source.path)")

        if options.debug {
            print("=============== time ===============")
            print("total time:", t3 - t1)
            print("  SyntaxParser.parse time:  ", t2 - t1)
            print("  rewriter.rewrite time:", t3 - t2)
            print("=============== result ===============")
            print()
        }
        else {
            if options.idempotent {
                // calculate diff
                // we assume that our code IS appended to string.
                // so, we must find prefix for source string in result string.
                var resultString = result.description
                if let range = resultString.range(of: sourceFile.description) {
                    resultString.removeSubrange(range)
                }
                try output.write(string: resultString)
            }
            else {
                try output.write(string: result.description)
            }
        }
    }

    private func _processFile(_ file: File, options: Options) throws
    {
        guard file.extension == "swift" else { return }

        let t1 = DispatchTime.now()

        let sourceFile: SourceFileSyntax =
            try Rewriter.parse(sourceFileURL: URL(fileURLWithPath: file.path))

        let t2 = DispatchTime.now()

        let result = rewriter.rewrite(sourceFile)

        let t3 = DispatchTime.now()

        print("Processing file: \(file.path)")

        if options.debug {
            print("=============== time ===============")
            print("total time:", t3 - t1)
            print("  SyntaxParser.parse time:  ", t2 - t1)
            print("  rewriter.rewrite time:", t3 - t2)
            print("=============== result ===============")
            print()
        }
        else {
            try file.write(string: result.description)
        }
    }

    private func _processFolder(_ folder: Folder, options: Options) throws
    {
        for file in folder.makeFileSequence(recursive: true, includeHidden: false) {
            try _processFile(file, options: options)
        }
    }
}

public struct RunOptions: OptionsProtocol
{
    fileprivate let path: String
    fileprivate let debug: Bool
    fileprivate let idempotent: Bool
    fileprivate let outputPath: String?

    public static func evaluate(_ m: CommandMode) -> Result<RunOptions, CommandantError<Swift.Error>>
    {
        return curry(Self.init)
            <*> m <| pathOption(action: "run")
            <*> m <| Switch(flag: "d", key: "debug", usage: "DEBUG")
            <*> m <| Switch(flag: "i", key: "idempotent", usage: "Use with flag --outputPath. It will output only diff after rewriting to outputPath file.")
            <*> m <| Option(key: "outputPath", defaultValue: nil, usage: "Use with flag --path. It will output to this file")
    }
}
