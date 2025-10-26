//
//  AssociatedTypes.swift
//  smockable
//

import SwiftSyntax
import SwiftSyntaxBuilder

enum AssociatedTypesGenerator {
    private static func getMappedAssociatedTypes(
        associatedTypes: [AssociatedTypeDeclSyntax]
    ) -> [(name: String, typeConformance: TypeConformance)] {
        return associatedTypes.map { associatedType in
            let typeConformances: [TypeConformance] =
                associatedType.inheritanceClause?.inheritedTypes.compactMap { syntax in
                    let components = syntax.description.split(separator: "&")
                    let trimmedComponents = components.map {
                        String($0.trimmingCharacters(in: .whitespacesAndNewlines))
                    }

                    let trimmedComponentsSet = Set(trimmedComponents)
                    let isComparable = trimmedComponentsSet.contains("Comparable")
                    let isEquatable = trimmedComponentsSet.contains("Equatable")

                    if isComparable {
                        return .comparableAndEquatable
                    } else if isEquatable {
                        return .onlyEquatable
                    } else {
                        return .neitherComparableNorEquatable
                    }
                } ?? []

            let typeConformance: TypeConformance = typeConformances.reduce(.neitherComparableNorEquatable) {
                partialResult,
                typeConformance in
                switch (partialResult, typeConformance) {
                case (_, .comparableAndEquatable):
                    return .comparableAndEquatable
                case (.onlyEquatable, _):
                    return .onlyEquatable
                case (_, .onlyEquatable):
                    return .onlyEquatable
                case (_, _):
                    return .neitherComparableNorEquatable
                }
            }

            return (associatedType.name.description, typeConformance)
        }
    }

    static func getTypeConformanceAssociatedTypes(
        associatedTypes: [AssociatedTypeDeclSyntax]
    )
        -> (comparableAndEquatable: [String], equatableOnly: [String])
    {
        if !associatedTypes.isEmpty {
            let mappedAssociatedTypes = getMappedAssociatedTypes(associatedTypes: associatedTypes)

            return mappedAssociatedTypes.reduce(([], [])) { partialResult, mappedAssociatedType in
                var updated = partialResult
                switch mappedAssociatedType.1 {
                case .comparableAndEquatable:
                    updated.0.append(mappedAssociatedType.0)
                case .onlyEquatable:
                    updated.1.append(mappedAssociatedType.0)
                case .neitherComparableNorEquatable:
                    break
                }

                return updated
            }
        } else {
            return ([], [])
        }
    }
}
