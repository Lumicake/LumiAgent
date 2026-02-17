//
//  DatabaseManager.swift
//  LumiAgent
//
//  Created by Lumi Agent on 2026-02-18.
//

import Foundation
import GRDB

// MARK: - Database Manager

/// Manages the application database connection and migrations
final class DatabaseManager {
    // MARK: - Singleton

    static let shared = DatabaseManager()

    // MARK: - Properties

    private(set) var dbQueue: DatabaseQueue!

    // MARK: - Initialization

    private init() {
        setupDatabase()
    }

    // MARK: - Setup

    private func setupDatabase() {
        do {
            let fileManager = FileManager.default
            let appSupport = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )

            let appFolder = appSupport.appendingPathComponent("LumiAgent", isDirectory: true)
            try fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true)

            let dbPath = appFolder.appendingPathComponent("lumi_agent.db").path
            dbQueue = try DatabaseQueue(path: dbPath)

            // Run migrations
            try runMigrations()

            print("✅ Database initialized at: \(dbPath)")
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }
    }

    // MARK: - Migrations

    private func runMigrations() throws {
        var migrator = DatabaseMigrator()

        // Migration v1: Initial schema
        migrator.registerMigration("v1_initial_schema") { db in
            // Agents table
            try db.create(table: "agents") { t in
                t.primaryKey("id", .text).notNull()
                t.column("name", .text).notNull()
                t.column("configuration", .text).notNull() // JSON
                t.column("capabilities", .text).notNull() // JSON array
                t.column("status", .text).notNull()
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
            }

            // Execution Sessions table
            try db.create(table: "execution_sessions") { t in
                t.primaryKey("id", .text).notNull()
                t.column("agent_id", .text).notNull()
                    .references("agents", onDelete: .cascade)
                t.column("user_prompt", .text).notNull()
                t.column("steps", .text).notNull() // JSON array
                t.column("result", .text) // JSON (nullable)
                t.column("status", .text).notNull()
                t.column("started_at", .datetime).notNull()
                t.column("completed_at", .datetime)
            }

            // Approval Requests table
            try db.create(table: "approval_requests") { t in
                t.primaryKey("id", .text).notNull()
                t.column("session_id", .text).notNull()
                    .references("execution_sessions", onDelete: .cascade)
                t.column("agent_id", .text).notNull()
                    .references("agents", onDelete: .cascade)
                t.column("tool_call", .text).notNull() // JSON
                t.column("risk_level", .text).notNull()
                t.column("reasoning", .text).notNull()
                t.column("estimated_impact", .text)
                t.column("status", .text).notNull()
                t.column("user_decision", .text) // JSON (nullable)
                t.column("requested_at", .datetime).notNull()
                t.column("decided_at", .datetime)
                t.column("expires_at", .datetime).notNull()
            }

            // Audit Logs table (append-only)
            try db.create(table: "audit_logs") { t in
                t.primaryKey("id", .text).notNull()
                t.column("event_type", .text).notNull()
                t.column("severity", .text).notNull()
                t.column("timestamp", .datetime).notNull()
                t.column("agent_id", .text)
                t.column("session_id", .text)
                t.column("user_id", .text)
                t.column("action", .text).notNull()
                t.column("target", .text)
                t.column("result", .text).notNull()
                t.column("details", .text) // JSON (nullable)
                t.column("ip_address", .text)
                t.column("hostname", .text)
            }

            // Indexes for performance
            try db.create(index: "idx_sessions_agent_id", on: "execution_sessions", columns: ["agent_id"])
            try db.create(index: "idx_sessions_started_at", on: "execution_sessions", columns: ["started_at"])
            try db.create(index: "idx_approvals_status", on: "approval_requests", columns: ["status"])
            try db.create(index: "idx_approvals_requested_at", on: "approval_requests", columns: ["requested_at"])
            try db.create(index: "idx_audit_timestamp", on: "audit_logs", columns: ["timestamp"])
            try db.create(index: "idx_audit_event_type", on: "audit_logs", columns: ["event_type"])
            try db.create(index: "idx_audit_severity", on: "audit_logs", columns: ["severity"])
        }

        // Future migrations will be added here
        // migrator.registerMigration("v2_add_feature") { db in ... }

        try migrator.migrate(dbQueue)
    }
}
