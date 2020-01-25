//
//  StoredPropertiesExtractor.swift
//  
//
//  Created by Dmitry Lobanov on 23.01.2020.
//

import SwiftSyntax

class StoredPropertiesExtractor: SyntaxRewriter {
    struct Options {
        var filterNames: [String] = []
    }
    class VariableFilter {
        struct Variable {
            static let zero = Variable()
            func isEmpty() -> Bool {
                return nameSyntax == nil
            }
            enum Accessor: CustomStringConvertible {
                case none
                case getter
                case setter
                func computed() -> Bool {
                    self == .getter
                }
                var description: String {
                    switch self {
                    case .none: return "none"
                    case .getter: return "getter"
                    case .setter: return "setter"
                    }
                }
            }
            var name: String? { nameSyntax?.description }
            var nameSyntax: PatternSyntax?
            var typeAnnotation: String? { typeAnnotationSyntax?.description }
            var typeAnnotationSyntax: TypeAnnotationSyntax?
            var accessor: Accessor = .none
            func computed() -> Bool { accessor.computed() }
            func unknownType() -> Bool { typeAnnotationSyntax == nil }
        }
        private func modifier(modifier: AccessorBlockSyntax?) -> Variable.Accessor {
            guard let modifier = modifier else { return .none }
            let emptySetters = modifier.accessors.enumerated().map {$0.element.accessorKind.tokenKind}.filter { .contextualKeyword("set") == $0 }.isEmpty
            return emptySetters ? .getter : .setter
        }
        private func accessor(accessor: Syntax?) -> Variable.Accessor {
            guard let accessor = accessor else { return .none }
            switch accessor {
            case is CodeBlockSyntax: return .getter
            case is AccessorBlockSyntax: return self.modifier(modifier: accessor as? AccessorBlockSyntax)
            default: return .none
            }
        }
        func variable(_ variable: VariableDeclSyntax) -> Variable {
            for binding in variable.bindings {
                var variable = Variable(nameSyntax: binding.pattern, typeAnnotationSyntax: binding.typeAnnotation)
                variable.accessor = self.accessor(accessor: binding.accessor)
                return variable
            }
            return .zero
        }
    }
    
    // MARK: Variables
    var options: Options = .init()
    // StructName -> (Struct, [MemberItem])
    var extractedFields: [String: (TypeSyntax, [VariableFilter.Variable])] = [:]
    
    var filter = VariableFilter()
    
    // MARK: Extraction
    func extract(_ node: StructDeclSyntax) -> [String: (TypeSyntax, [VariableFilter.Variable])] {
        let syntax = node
        let variables = syntax.members.members.enumerated().compactMap{ $0.element.decl as? VariableDeclSyntax }.map(self.filter.variable).filter{
            !($0.isEmpty() || $0.computed() || $0.unknownType())
        }
        
        let identifier = syntax.fullIdentifier.description.trimmingCharacters(in: .whitespacesAndNewlines)
        self.extractedFields[identifier] = (syntax.fullIdentifier, variables)
        
        return self.extractedFields
    }
    
    // MARK: Visits
    override func visit(_ node: StructDeclSyntax) -> DeclSyntax {
        _ = self.extract(node)
        return super.visit(node)
    }
}
