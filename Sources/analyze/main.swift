import Foundation
import DMARCAnalyzer
import CommandLineParser

let parser = Parser(arguments: CommandLine.arguments)
do {
    try DMARCAnalyzerCommand.handler(parser: parser)
}
catch {
    print("\(error)")
    exit(1)
}
