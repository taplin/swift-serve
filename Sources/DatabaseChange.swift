//
//  DatabaseChange.swift
//  drewag.me
//
//  Created by Andrew J Wagner on 3/18/17.
//
//

import SQL

public protocol DatabaseChange {
    var forwardQuery: String {get}
    var revertQuery: String? {get}
}

public struct FieldReference {
    public enum Action: String {
        case none = "NO ACTION"
        case cascade = "CASCADE"
        case setNull = "SET NULL"
        case setDefault = "SET DEFAULT"
    }

    let table: String
    let field: String
    let onDelete: Action
    let onUpdate: Action

    init(table: String, field: String, onDelete: Action = .none, onUpdate: Action = .none) {
        self.table = table
        self.field = field
        self.onDelete = onDelete
        self.onUpdate = onUpdate
    }

    public static func field(_ field: String, in table: String, onDelete: Action = .none, onUpdate: Action = .none) -> FieldReference {
        return FieldReference(table: table, field: field, onDelete: onDelete, onUpdate: onUpdate)
    }

    public static func field<Field: TableField>(_ field: Field, onDelete: Action = .none, onUpdate: Action = .none) -> FieldReference where Field.RawValue == String {
        return self.field(field.rawValue, in: Field.tableName, onDelete: onDelete, onUpdate: onUpdate)
    }
}

public struct Constraint: CustomStringConvertible {
    public enum Kind {
        case unique([String])
    }

    let name: String
    let kind: Kind

    public init(name: String, kind: Kind) {
        self.name = name
        self.kind = kind
    }

    public var description: String {
        var description = "CONSTRAINT \(self.name) "
        switch kind {
        case .unique(let unique):
            description += "UNIQUE ("
            description += unique.joined(separator: ",")
            description += ")"
        }
        return description
    }
}

public struct FieldSpec: CustomStringConvertible {
    public enum DataType {
        case string(length: Int?)
        case timestamp
        case timestampWithTimeZone
        case interval
        case ipAddress
        case date
        case bool
        case serial
        case integer
        case double
    }

    let name: String
    let allowNull: Bool
    let isUnique: Bool
    let isPrimaryKey: Bool
    let type: DataType
    let references: FieldReference?

    public init(name: String, type: DataType, allowNull: Bool = true, isUnique: Bool = false, references: FieldReference? = nil) {
        self.name = name
        self.type = type
        self.allowNull = allowNull
        self.isUnique = isUnique
        self.isPrimaryKey = false
        self.references = references
    }

    public init(name: String, type: DataType, isPrimaryKey: Bool) {
        self.name = name
        self.type = type
        self.isPrimaryKey = isPrimaryKey
        self.references = nil

        // Setting these will mean they won't be added to the command
        self.allowNull = true
        self.isUnique = false
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
        case .timestampWithTimeZone:
            description += "timestamp with time zone"
        case .string(let length):
            if let length = length {
                description += "varchar(\(length))"
            }
            else {
                description += "varchar"
            }
        case .bool:
            description += "boolean"
        case .serial:
            description += "SERIAL"
        case .integer:
            description += "integer"
        case .double:
            description += "double precision"
        case .interval:
            description += "interval"
        }
        if isPrimaryKey {
            description += " PRIMARY KEY"
        }
        if isUnique {
            description += " UNIQUE"
        }
        if !self.allowNull {
            description += " NOT NULL"
        }
        if let references = self.references {
            description += " REFERENCES \(references.table)(\(references.field))"
            description += " ON DELETE \(references.onDelete.rawValue) ON UPDATE \(references.onUpdate.rawValue)"
        }
        return description
    }
}

public struct CreateTable: DatabaseChange {
    let name: String
    let fields: [FieldSpec]
    let constraints: [Constraint]
    let primaryKey: [String]

    public init(name: String, fields: [FieldSpec], primaryKey: [String] = [], constraints: [Constraint] = []) {
        self.name = name
        self.fields = fields
        self.primaryKey = primaryKey
        self.constraints = constraints
    }

    public var forwardQuery: String {
        var query = "CREATE TABLE \(name) ("
        var specs = self.fields.map({$0.description})
        if !self.primaryKey.isEmpty {
            specs.append("PRIMARY KEY (\(self.primaryKey.joined(separator: ",")))")
        }
        specs += self.constraints.map({$0.description})
        query += specs.joined(separator: ",")
        query += ")"
        return query
    }

    public var revertQuery: String? {
        return "DROP TABLE \(name)"
    }
}

public struct AddColumn: DatabaseChange {
    let table: String
    let spec: FieldSpec

    public init(to table: String, with spec: FieldSpec) {
        self.table = table
        self.spec = spec
    }

    public var forwardQuery: String {
        return "ALTER TABLE \(table) ADD COLUMN \(spec.description)"
    }

    public var revertQuery: String? {
        return "DROP COLUMN \(self.spec.name)"
    }
}

public struct InsertRow: DatabaseChange {
    let table: String
    let values: [String]

    public init(into table: String, values: [String]) {
        self.table = table
        self.values = values
    }

    public var forwardQuery: String {
        var query = "INSERT INTO \(self.table) VALUES ("
        query += self.values.joined(separator: ",")
        query += ")"
        return query
    }

    public var revertQuery: String? {
        return nil
    }
}
