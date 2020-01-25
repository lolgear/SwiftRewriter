//
//  RequestResponseExtensionGeneratorTests.swift
//  
//
//  Created by Dmitry Lobanov on 24.01.2020.
//

import XCTest
@testable import SwiftRewriter


/*
// input
struct Outer {
    struct Fruit {
        struct Apple {
            struct Request {
                var name: String = .init()
                var seedCount: Int = .init()
                struct Kind {}
            }
            struct Response {
                struct Error {
                    struct Code {}
                }
            }
        }
        struct Raspberry {
            struct Request {
                var name: String = .init()
                var seed: String = .init()
                struct Kind {}
            }
            struct Response {
                struct Error {
                    struct Code {}
                }
            }
        }
    }
}
// result
extension Fruit.Apple {
    struct Invocation {/**/}
    struct Service {
        // public function
        // template
    }
}
extension Fruit.Raspberry {
    struct Invocation {/**/}
    struct Service {
        // public function
        // template
    }
}
*/

final class RequestResponseExtensionGeneratorTests: XCTestCase
{
    func test_basic() throws
    {
        let source = """
            struct Outer {
                struct Fruit {
                    struct Apple {
                        struct Request {
                            var name: String = .init()
                            var seedCount: Int = .init()
                            struct Kind {}
                        }
                        struct Response {
                            struct Error {
                                struct Code {}
                            }
                        }
                    }
                    struct Raspberry {
                        struct Request {
                            var name: String = .init()
                            var seed: String = .init()
                            struct Kind {}
                        }
                        struct Response {
                            struct Error {
                                struct Code {}
                            }
                        }
                    }
                }
            }
            """
        
        let expected = """
            extension Fruit.Apple {
                struct Invocation {/**/}
                struct Service {
                    // public function
                    // template
                }
            }
            extension Fruit.Raspberry {
                struct Invocation {/**/}
                struct Service {
                    // public function
                    // template
                }
            }
            """
        
        try runTest(
            source: source,
            expected: expected,
            using: RequestResponseExtensionGenerator()
        )
    }
}
