//
//  MemberwiseConvenientInitializerGenerator.swift
//  
//
//  Created by Dmitry Lobanov on 21.01.2020.
//

import SwiftSyntax

extension SyntaxRewriter {
    public class Empty: SyntaxRewriter {
        open override func visit(_ syntax: SourceFileSyntax) -> Syntax {
            super.visit(syntax)
        }
    }
}
// NOTE: Extract necessary fields for structure.
// 1. Get structure full name.
// 2. Create extension.
// 3. Add initializer with extension.
open class MemberwiseConvenientInitializerGenerator: SyntaxRewriter {
    public var options: Options = .init()
    open override func visit(_ syntax: SourceFileSyntax) -> Syntax {
        let fieldsExtractor = NecessaryFieldsExtractor()
        _ = fieldsExtractor.visit(syntax) as! SourceFileSyntax
        // we don't care about changing, we only need parsing variables.
        
        var items: [CodeBlockItemSyntax] = []
        
        for (_, fields) in fieldsExtractor.storedPropertiesExtractor.extractedFields.sorted(by: { (lhs, rhs) -> Bool in
            lhs.key < rhs.key
        }) {
            let (structure, storedVariables) = fields
            let variablesNamesAndTypes = storedVariables.map({($0.name, $0.typeAnnotationSyntax?.type)}).filter{$0.0 != nil && $0.1 != nil}
            guard !variablesNamesAndTypes.isEmpty else { continue }

            let newItem = SyntaxFactory.makeCodeBlockItem(
                item: SyntaxFactory.makeExtensionDecl(
                    attributes: nil,
                    modifiers: nil,
                    extensionKeyword: SyntaxFactory.makeExtensionKeyword(
                        leadingTrivia: [.newlines(2)],
                        trailingTrivia: [.spaces(1)]
                    ),
                    extendedType: structure,
                    inheritanceClause: nil,
                    genericWhereClause: nil,
                    members: MemberDeclBlockSyntax.init({ builder in
                        builder.useLeftBrace(SyntaxFactory.makeLeftBraceToken(leadingTrivia: [.spaces(1)], trailingTrivia: [.newlines(1)]))
                        /*
                         init(internalError: Error, error: Error) {
                             self.internalError = internalError
                             self.error = error
                         }
                         */
                        
                        let functionParameters = variablesNamesAndTypes.compactMap { (name, type) -> FunctionParameterSyntax? in
                            guard let name = name, let type = type else { return nil }
                            // TODO: Remove trailingTrivia somehow... type is immutable :(
                            let typeName = type.description.trimmingCharacters(in: .whitespacesAndNewlines)
                            return FunctionParameterSyntax { b in
                                b.useFirstName(SyntaxFactory.makeIdentifier(name))
                                b.useColon(SyntaxFactory.makeColonToken(trailingTrivia: [.spaces(1)]))
                                b.useType(SyntaxFactory.makeTypeIdentifier(typeName))
                                if name != variablesNamesAndTypes.last?.0 {
                                    b.useTrailingComma(SyntaxFactory.makeCommaToken(trailingTrivia: [.spaces(1)]))
                                }
                            }
                        }
                        
                        let parameters = ParameterClauseSyntax { b in
                            b.useLeftParen(SyntaxFactory.makeLeftParenToken())
                            for parameter in functionParameters {
                                b.addParameter(parameter)
                            }
                            b.useRightParen(SyntaxFactory.makeRightParenToken(leadingTrivia: [.spaces(0)], trailingTrivia: [.spaces(0)]))
                        }

                        let statements = variablesNamesAndTypes.compactMap {$0.0}.compactMap { name -> CodeBlockItemSyntax in
                            CodeBlockItemSyntax { b in
                                let left: [CodeBlockItemSyntax] = [
                                    .init{ b in b.useItem(SyntaxFactory.makeSelfKeyword()) },
                                    .init{ b in b.useItem(SyntaxFactory.makeToken(.contextualKeyword("."), presence: .present)) },
                                    .init{ b in b.useItem(SyntaxFactory.makeIdentifier(name)) },
                                ]
                                let assignment = SyntaxFactory.makeAssignmentExpr(assignToken: SyntaxFactory.makeToken(.equal, presence: .present)).withLeadingTrivia([.spaces(1)]).withTrailingTrivia([.spaces(1)])
                                
                                let right = SyntaxFactory.makeIdentifier(name)
                                
                                let full: [CodeBlockItemSyntax] = left + [
                                    .init{ b in b.useItem(assignment) },
                                    .init{ b in b.useItem(right) },
                                ]
                                
                                b.useItem(SyntaxFactory.makeCodeBlockItemList(full))
                            }
                        }
                        
                        
                        let singleLeadingTrivia: Trivia = [.spaces(4)] //[.tabs(1)]
                        let doubleLeadingTrivia: Trivia = [.spaces(8)] //[.tabs(2)]
                        let body = CodeBlockSyntax { b in
                            b.useLeftBrace(SyntaxFactory.makeLeftBraceToken().withTrailingTrivia([.newlines(1)]))
                            for statement in statements {
                                b.addStatement(statement.withTrailingTrivia([.newlines(1)]).withLeadingTrivia(doubleLeadingTrivia))
                            }
                            b.useRightBrace(SyntaxFactory.makeRightBraceToken().withTrailingTrivia([.newlines(1)]).withLeadingTrivia(singleLeadingTrivia))
                        }
                                                
                        let initializer = InitializerDeclSyntax { b in
                            b.useInitKeyword(SyntaxFactory.makeInitKeyword())
                            b.useParameters(parameters.withTrailingTrivia([.spaces(1)]))
                            b.useBody(body)
                        }
                                                
                        builder.addMember( MemberDeclListItemSyntax{ b in
                            b.useDecl(initializer.withLeadingTrivia(singleLeadingTrivia))
                        })
                        builder.useRightBrace(SyntaxFactory.makeRightBraceToken(leadingTrivia: [.newlines(0)]))
                    })),
                semicolon: nil,
                errorTokens: nil
            )
            items.append(newItem)
        }
        
        if items.count > 0 {
            let resultItem = CodeBlockItemSyntax { b in
                b.useItem(SyntaxFactory.makeCodeBlockItemList(items))
            }
//            let newSyntax =
//                SourceFileSyntax { b in
//                    b.addStatement(resultItem)
//            }
            return super.visit(syntax.addStatement(resultItem))
        }
        else {
            return super.visit(syntax)
        }
    }
}

public extension MemberwiseConvenientInitializerGenerator {
    class Options {
        var structuresNames: [String] = [] // will contain Request/Response.
        var fieldsNames: [String] = [] // will contain unknownFields.
        var shouldSkipComputedVariables: Bool = true
        var shouldSkipUnknownTypeVariables: Bool = true
        func hasStructuresNames() -> Bool { !structuresNames.isEmpty }
        func hasFieldsNames() -> Bool { !fieldsNames.isEmpty }
    }
}

// NOTE: Necessary fields definition
// 1. Filtered Fields count > 0
// 2. Fields has get and setter.
private extension MemberwiseConvenientInitializerGenerator {
    class NecessaryFieldsExtractor: SyntaxRewriter {
        var storedPropertiesExtractor = StoredPropertiesExtractor()
        
        // MARK: Visits
        open override func visit(_ syntax: StructDeclSyntax) -> DeclSyntax {
            _ = self.storedPropertiesExtractor.visit(syntax)
            return super.visit(syntax)
        }
    }
}

extension MemberwiseConvenientInitializerGenerator: Generator {
    public func generate(_ node: SourceFileSyntax) -> Syntax {
        let fieldsExtractor = NecessaryFieldsExtractor()
        _ = fieldsExtractor.visit(node)
        // we don't care about changing, we only need parsing variables.
        
        var items: [CodeBlockItemSyntax] = []
        
        for (_, fields) in fieldsExtractor.storedPropertiesExtractor.extractedFields.sorted(by: { (lhs, rhs) -> Bool in
            lhs.key < rhs.key
        }) {
            let (structure, storedVariables) = fields
            let variablesNamesAndTypes = storedVariables.map({($0.name, $0.typeAnnotationSyntax?.type)}).filter{$0.0 != nil && $0.1 != nil}
            guard !variablesNamesAndTypes.isEmpty else { continue }

            let newItem = SyntaxFactory.makeCodeBlockItem(
                item: SyntaxFactory.makeExtensionDecl(
                    attributes: nil,
                    modifiers: nil,
                    extensionKeyword: SyntaxFactory.makeExtensionKeyword(
                        leadingTrivia: [.newlines(2)],
                        trailingTrivia: [.spaces(1)]
                    ),
                    extendedType: structure,
                    inheritanceClause: nil,
                    genericWhereClause: nil,
                    members: MemberDeclBlockSyntax.init({ builder in
                        builder.useLeftBrace(SyntaxFactory.makeLeftBraceToken(leadingTrivia: [.spaces(1)], trailingTrivia: [.newlines(1)]))
                        /*
                         init(internalError: Error, error: Error) {
                             self.internalError = internalError
                             self.error = error
                         }
                         */
                        
                        let functionParameters = variablesNamesAndTypes.compactMap { (name, type) -> FunctionParameterSyntax? in
                            guard let name = name, let type = type else { return nil }
                            // TODO: Remove trailingTrivia somehow... type is immutable :(
                            let typeName = type.description.trimmingCharacters(in: .whitespacesAndNewlines)
                            return FunctionParameterSyntax { b in
                                b.useFirstName(SyntaxFactory.makeIdentifier(name))
                                b.useColon(SyntaxFactory.makeColonToken(trailingTrivia: [.spaces(1)]))
                                b.useType(SyntaxFactory.makeTypeIdentifier(typeName))
                                if name != variablesNamesAndTypes.last?.0 {
                                    b.useTrailingComma(SyntaxFactory.makeCommaToken(trailingTrivia: [.spaces(1)]))
                                }
                            }
                        }
                        
                        let parameters = ParameterClauseSyntax { b in
                            b.useLeftParen(SyntaxFactory.makeLeftParenToken())
                            for parameter in functionParameters {
                                b.addParameter(parameter)
                            }
                            b.useRightParen(SyntaxFactory.makeRightParenToken(leadingTrivia: [.spaces(0)], trailingTrivia: [.spaces(0)]))
                        }

                        let statements = variablesNamesAndTypes.compactMap {$0.0}.compactMap { name -> CodeBlockItemSyntax in
                            CodeBlockItemSyntax { b in
                                let left: [CodeBlockItemSyntax] = [
                                    .init{ b in b.useItem(SyntaxFactory.makeSelfKeyword()) },
                                    .init{ b in b.useItem(SyntaxFactory.makeToken(.contextualKeyword("."), presence: .present)) },
                                    .init{ b in b.useItem(SyntaxFactory.makeIdentifier(name)) },
                                ]
                                let assignment = SyntaxFactory.makeAssignmentExpr(assignToken: SyntaxFactory.makeToken(.equal, presence: .present)).withLeadingTrivia([.spaces(1)]).withTrailingTrivia([.spaces(1)])
                                
                                let right = SyntaxFactory.makeIdentifier(name)
                                
                                let full: [CodeBlockItemSyntax] = left + [
                                    .init{ b in b.useItem(assignment) },
                                    .init{ b in b.useItem(right) },
                                ]
                                
                                b.useItem(SyntaxFactory.makeCodeBlockItemList(full))
                            }
                        }
                        
                        
                        let singleLeadingTrivia: Trivia = [.spaces(4)] //[.tabs(1)]
                        let doubleLeadingTrivia: Trivia = [.spaces(8)] //[.tabs(2)]
                        let body = CodeBlockSyntax { b in
                            b.useLeftBrace(SyntaxFactory.makeLeftBraceToken().withTrailingTrivia([.newlines(1)]))
                            for statement in statements {
                                b.addStatement(statement.withTrailingTrivia([.newlines(1)]).withLeadingTrivia(doubleLeadingTrivia))
                            }
                            b.useRightBrace(SyntaxFactory.makeRightBraceToken().withTrailingTrivia([.newlines(1)]).withLeadingTrivia(singleLeadingTrivia))
                        }
                                                
                        let initializer = InitializerDeclSyntax { b in
                            b.useInitKeyword(SyntaxFactory.makeInitKeyword())
                            b.useParameters(parameters.withTrailingTrivia([.spaces(1)]))
                            b.useBody(body)
                        }
                                                
                        builder.addMember( MemberDeclListItemSyntax{ b in
                            b.useDecl(initializer.withLeadingTrivia(singleLeadingTrivia))
                        })
                        builder.useRightBrace(SyntaxFactory.makeRightBraceToken(leadingTrivia: [.newlines(0)]))
                    })),
                semicolon: nil,
                errorTokens: nil
            )
            items.append(newItem)
        }
                
        return SyntaxFactory.makeSourceFile(statements: SyntaxFactory.makeCodeBlockItemList(items), eofToken: SyntaxFactory.makeToken(.eof, presence: .present))
    }
}
