//
//  DatabaseChange.swift
//  drewag.me
//
//  Created by Andrew J Wagner on 3/18/17.
//
//

public protocol DatabaseChange {
    var forwardQuery: String {get}
    var revertQuery: String {get}
}

public struct FieldSpec: CustomStringConvertible {
    public enum DataType {
        case string(length: Int?)
        case timestamp
        case ipAddress
        case date
    }

    let name: String
    let allowNull: Bool
    let isUnique: Bool
    let type: DataType

    public init(name: String, type: DataType, allowNull: Bool = true, isUnique: Bool = false) {
        self.name = name
        self.type = type
        self.allowNull = allowNull
        self.isUnique = isUnique
    }

    public var description: String {
        var description = "\(self.name) "
        switch self.type {
        case .date:
            description += "date"
        case .ipAddress:
            description += "inet"
        case .timestamp:
            description += "timestamp"
        case .string(let length):
            if let length = length {
                description += "varchar(\(length))"
            }
            else {
                description += "varchar"
            }
        }
        if isUnique {
            description += " UNIQUE"
        }
        if !self.allowNull {
            description += " NOT NULL"
        }
        return description
    }
}

public struct CreateTable: DatabaseChange {
    let name: String
    let fields: [FieldSpec]

    public init(name: String, fields: [FieldSpec]) {
        self.name = name
        self.fields = fields
    }

    public var forwardQuery: String {
        var query = "CREATE TABLE \(name) ("
        query += self.fields.map({$0.description}).joined(separator: ",")
        query += ")"
        return query
    }

    public var revertQuery: String {
        return "DROP TABLE \(name)"
    }
}