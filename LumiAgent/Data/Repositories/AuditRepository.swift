//
//  AuditRepository.swift
//  LumiAgent
//
//  Created by Lumi Agent on 2026-02-18.
//

import Foundation
import GRDB

// MARK: - Audit Repository

final class AuditRepository: AuditRepositoryProtocol {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    func log(_ entry: AuditLog) async throws {
        // Append-only, no updates or deletes
        try await dbQueue.write { db in
            try entry.insert(db)
        }
    }

    func query(_ query: AuditQuery) async throws -> [AuditLog] {
        try await dbQueue.read { db in
            var request = AuditLog.all()

            // Apply filters
            if let startDate = query.startDate {
                request = request.filter(AuditLog.Columns.timestamp >= startDate)
            }
            if let endDate = query.endDate {
                request = request.filter(AuditLog.Columns.timestamp <= endDate)
            }
            if let eventTypes = query.eventTypes, !eventTypes.isEmpty {
                let eventTypeStrings = eventTypes.map { $0.rawValue }
                request = request.filter(eventTypeStrings.contains(AuditLog.Columns.eventType))
            }
            if let severities = query.severities, !severities.isEmpty {
                let severityStrings = severities.map { $0.rawValue }
                request = request.filter(severityStrings.contains(AuditLog.Columns.severity))
            }
            if let agentIds = query.agentIds, !agentIds.isEmpty {
                let agentIdStrings = agentIds.map { $0.uuidString }
                request = request.filter(agentIdStrings.contains(AuditLog.Columns.agentId))
            }
            if let sessionIds = query.sessionIds, !sessionIds.isEmpty {
                let sessionIdStrings = sessionIds.map { $0.uuidString }
                request = request.filter(sessionIdStrings.contains(AuditLog.Columns.sessionId))
            }
            if let searchText = query.searchText, !searchText.isEmpty {
                request = request.filter(
                    AuditLog.Columns.action.like("%\(searchText)%") ||
                    AuditLog.Columns.target.like("%\(searchText)%")
                )
            }

            // Order by timestamp descending
            request = request.order(AuditLog.Columns.timestamp.desc)

            // Apply limit (offset not directly supported in GRDB QueryInterfaceRequest)
            if let limit = query.limit {
                request = request.limit(limit)
            }

            // Fetch and manually skip offset if needed
            let allResults = try request.fetchAll(db)
            if let offset = query.offset, offset > 0 {
                return Array(allResults.dropFirst(offset))
            }
            return allResults
        }
    }

    func export(query: AuditQuery) async throws -> URL {
        let logs = try await self.query(query)

        // Create CSV export
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        let filename = "audit_export_\(Date().timeIntervalSince1970).csv"
        let fileURL = tempDir.appendingPathComponent(filename)

        var csvString = "ID,Event Type,Severity,Timestamp,Agent ID,Session ID,User ID,Action,Target,Result\n"

        for log in logs {
            let row = [
                log.id.uuidString,
                log.eventType.rawValue,
                log.severity.rawValue,
                ISO8601DateFormatter().string(from: log.timestamp),
                log.agentId?.uuidString ?? "",
                log.sessionId?.uuidString ?? "",
                log.userId ?? "",
                log.action.replacingOccurrences(of: ",", with: ";"),
                log.target ?? "",
                log.result.rawValue
            ].joined(separator: ",")

            csvString += row + "\n"
        }

        try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
