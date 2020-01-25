//
//  PublicInvocationGeneratorTests.swift
//  
//
//  Created by Dmitry Lobanov on 24.01.2020.
//

import XCTest
@testable import SwiftRewriter
 
final class PublicInvocationGeneratorTests: XCTestCase
{
    func test_basic() throws
    {
        let source = """
            struct Invocation {
            }
            """

        let expected = """
            struct Invocation {
                static func invoke(_ data: Data?) -> Data? {
                    Lib.LibAbcDef(data)
                }
            }
            """

        try runTest(
            source: source,
            expected: expected,
            using: PublicInvocationGenerator()
        )
    }
}
