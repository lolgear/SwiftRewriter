//
//  RequestResponseExtensionGenerator.swift
//  
//
//  Created by Dmitry Lobanov on 24.01.2020.
//

import SwiftSyntax
public class RequestResponseExtensionGenerator: SyntaxRewriter {
    struct Options {
        var serviceName: String = "Service"
        var templatePaths: [String] = []
        var requestName: String = "Request"
        var responseName: String = "Response"
    }
    
    var options: Options = .init()
    init(options: Options) {
        self.options = options
    }
    public override init() {}
    
    public func with(templatePaths: [String]) -> Self {
        self.options.templatePaths = templatePaths
        return self
    }
    
    typealias DeclarationNotation = NestedTypesScanner.DeclarationNotation
    struct Scope {
        var this: DeclarationNotation = .init()
        var request: DeclarationNotation = .init()
        var response: DeclarationNotation = .init()
    }
    
    enum Part {
        struct Options {
            var serviceName: String = ""
            var scope: Scope = .init()
        }
        case service(Options)
        case scope(Options)
    }
    enum PartResult {
        case service(Syntax)
        case scope(Syntax)
        func raw() -> Syntax {
            switch self {
            case let .service(value): return value
            case let .scope(value): return value
            }
        }
    }
    
    var nestedTypesScanner: NestedTypesScanner = .init()
    // TODO: Make later service generator separately.
    var templateGenerator: TemplateGenerator = .init()
    var publicInvocationGenerator: PublicInvocationGenerator = .init()
    var storedPropertiesExtractor: StoredPropertiesExtractor = .init()
    enum ServicePart {
        case publicInvocation(Scope)
        case template
    }
    
    // MARK: Scan
    func matchNested(_ declaration: DeclarationNotation, identifier: String) -> DeclarationNotation? {
        return declaration.declarations.first(where: {$0.identifier == identifier})
    }
    
    func match(_ declaration: DeclarationNotation) -> Scope? {
        if let request = self.matchNested(declaration, identifier: self.options.requestName),
           let response = self.matchNested(declaration, identifier: self.options.requestName) {
            return .init(this: declaration, request: request, response: response)
        }
        return nil
    }
    
    func scan(_ declaration: DeclarationNotation) -> [Scope] {
        [self.match(declaration)].compactMap{$0} + declaration.declarations.flatMap(self.scan)
    }
    
    func scan(_ node: SourceFileSyntax) -> [Scope] {
        let result = self.nestedTypesScanner.scan(node).flatMap(self.scan)
        return result
    }
    
    // MARK: Visits
    override public func visit(_ node: SourceFileSyntax) -> Syntax {
        let result = self.generate(node)
        print("result: \(result)")
        return super.visit(node)
    }
}

extension RequestResponseExtensionGenerator: Generator {
    func generate(servicePart: ServicePart, options: Options) -> [DeclSyntax] {
        switch servicePart {
        case let .publicInvocation(scope):
            let structIdentifier = scope.request.fullIdentifier
            let properties = (scope.request.syntax as? StructDeclSyntax).flatMap(self.storedPropertiesExtractor.extract)
            let variables = properties?[structIdentifier]?.1
            let result = variables.flatMap{self.publicInvocationGenerator.with(variables: $0)}.map{$0.generate(.function)}
            return [result].flatMap{$0 as? DeclSyntax}
        case .template:
            options.templatePaths.first
                .flatMap(self.templateGenerator.generate)
                .flatMap{$0 as? SourceFileSyntax}
                .flatMap{$0.statements}
                .flatMap{$0 as? DeclSyntax}
            if let result = options.templatePaths.first.flatMap(self.templateGenerator.generate) as? SourceFileSyntax {
                return result.statements.compactMap{$0.item as? DeclSyntax}
            }
            return []
        }
    }
    func generate(part: Part, options: Options) -> Syntax {
        switch part {
        case let .service(value):
            let publicKeyword = SyntaxFactory.makePublicKeyword()
            let serviceName = value.serviceName
            let serviceNameIdentifier = SyntaxFactory.makeIdentifier(serviceName)
            // our result is enum
            
            // fill enum
            let memberDeclList: [MemberDeclListItemSyntax] = [self.generate(servicePart: .publicInvocation(value.scope), options: options), self.generate(servicePart: .template, options: options)].flatMap{$0}.compactMap{entry in MemberDeclListItemSyntax.init{b in b.useDecl(entry)}}
                                                
            let memberDeclListSyntax = SyntaxFactory.makeMemberDeclList(memberDeclList)
            let memberDeclBlockSyntax = SyntaxFactory.makeMemberDeclBlock(leftBrace: SyntaxFactory.makeLeftBraceToken().withLeadingTrivia(.spaces(1)).withTrailingTrivia(.newlines(1)), members: memberDeclListSyntax, rightBrace: SyntaxFactory.makeRightBraceToken().withLeadingTrivia(.newlines(1)).withTrailingTrivia(.newlines(1)))
            let attributesListSyntax = SyntaxFactory.makeAttributeList([
                publicKeyword.withTrailingTrivia(.spaces(1))
            ])
            let result = SyntaxFactory.makeEnumDecl(attributes: attributesListSyntax, modifiers: nil, enumKeyword: SyntaxFactory.makeEnumKeyword().withLeadingTrivia(.newlines(1)).withTrailingTrivia(.spaces(1)), identifier: serviceNameIdentifier, genericParameters: nil, inheritanceClause: nil, genericWhereClause: nil, members: memberDeclBlockSyntax)
            return result
            
        case let .scope(value):
            let scopeName = value.scope.this.fullIdentifier
            let scopeTypeSyntax = SyntaxFactory.makeTypeIdentifier(scopeName)
            // NOTE: scopeName except first scope. Custom behaviour.
            let className = scopeName.split(separator: ".").dropFirst().joined()
            
            // first, add invocation
            let generator = PrivateInvocationGenerator().with(className: className)
            let invocationSyntax = generator.generate(.structure).raw()
            
            // next, add service
            let serviceSyntax = self.generate(part: .service(value), options: self.options)
            
            // build members
            let memberDeclList: [MemberDeclListItemSyntax] = [invocationSyntax, serviceSyntax].compactMap{$0 as? DeclSyntax}.compactMap{entry in MemberDeclListItemSyntax.init{b in b.useDecl(entry)}}
            let memberDeclListSyntax = SyntaxFactory.makeMemberDeclList(memberDeclList)
            let memberDeclBlockSyntax = SyntaxFactory.makeMemberDeclBlock(leftBrace: SyntaxFactory.makeLeftBraceToken().withLeadingTrivia(.spaces(1)).withTrailingTrivia(.newlines(1)), members: memberDeclListSyntax, rightBrace: SyntaxFactory.makeRightBraceToken().withTrailingTrivia(.newlines(1)))
            
            let result = SyntaxFactory.makeExtensionDecl(attributes: nil, modifiers: nil, extensionKeyword: SyntaxFactory.makeExtensionKeyword().withLeadingTrivia(.newlines(1)).withTrailingTrivia(.spaces(1)), extendedType: scopeTypeSyntax, inheritanceClause: nil, genericWhereClause: nil, members: memberDeclBlockSyntax)
            // and build extension
            return result
        }
    }
    func generate(scope: Scope) -> Syntax {
        self.generate(part: .scope(.init(serviceName: self.options.serviceName, scope: scope)), options: self.options)
    }
    public func generate(_ node: SourceFileSyntax) -> Syntax {
        let syntaxList = self.scan(node).compactMap(self.generate)
        let codeBlockItemListSyntax = syntaxList.compactMap {entry in CodeBlockItemSyntax.init{b in b.useItem(entry)}}
        let result = SyntaxFactory.makeSourceFile(statements: SyntaxFactory.makeCodeBlockItemList(codeBlockItemListSyntax), eofToken: SyntaxFactory.makeToken(.eof, presence: .present))
        return result
    }
}

struct ABC {
    static func example() {
        let a = [CustomStringConvertible]().compactMap(To.as(String.self))
        let b = a.flatMap(Cast<String>.as)
    }
}

struct To<From> {
    let value: From
    init(_ value: From) {
        self.value = value
    }
    
    static func `as`<T>(_ to: T.Type) -> (From) -> Optional<T> { { $0 as? T} }
    
//    static func ≈<From, To>(_ lhs: From, _ rhs: To.Type) -> Optional<To> {
//        lhs as? To
//    }
}

struct Cast<T> {
    static func `as`<F>(_ from: F) -> (F) -> Optional<T> { { $0 as? T } }
}

//infix operator ≈: MultiplicationPrecedence
