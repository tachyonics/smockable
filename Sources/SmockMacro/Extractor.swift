//===----------------------------------------------------------------------===//
//
// This source file is part of the Smockable open source project
//
// Copyright (c) 2026 the Smockable authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Smockable authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

//
//  Extractor.swift
//  SmockMacro
//

import SwiftSyntax

/// `Extractor` is designed to extract a `ProtocolDeclSyntax` instance
/// from a given `DeclSyntaxProtocol` instance.
///
/// It contains a single method, `extractProtocolDeclaration(from:)`, which
/// attempts to cast the input `DeclSyntaxProtocol` into a `ProtocolDeclSyntax`.
/// If the cast is successful, the method returns the `ProtocolDeclSyntax`. If the cast fails,
/// meaning the input declaration is not a protocol declaration, the method throws
/// a `SmockDiagnostic.onlyApplicableToProtocol` error.
enum Extractor {
    static func extractProtocolDeclaration(
        from declaration: DeclSyntaxProtocol
    ) throws
        -> ProtocolDeclSyntax
    {
        guard let protocolDeclaration = declaration.as(ProtocolDeclSyntax.self) else {
            throw SmockDiagnostic.onlyApplicableToProtocol
        }

        return protocolDeclaration
    }
}
