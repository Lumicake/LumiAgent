//
//  AuditLogger.swift
//  LumiAgent
//
//  Created by Lumi Agent on 2026-02-18.
//
//  Centralized audit logging service
//

import Foundation
import Logging

// MARK: - Audit Logger

/// Centralized service for audit logging
final class AuditLogger {
    // MARK: - Singleton

    static let shared = AuditLogger()

    // MARK: - Properties

    private let repository: AuditRepositoryProtocol
    private let logger = Logger(label: "com.lumiagent.audit")

    // MARK: - Initialization

    private init() {
        self.repository = AuditRepository()
    }

    // MARK: - Logging Methods

    /// Log a command execution
    func logCommandExecution(
        command: String,
        target: String?,
        result: AuditResult,
        agentId: UUID?,
        sessionId: UUID?,
        details: [String: String]? = nil
    ) async {
        await log(
            eventType: .commandExecuted,
            severity: result == .success ? .info : .error,
            agentId: agentId,
            sessionId: sessionId,
            action: "Executed: \(command)",
            target: target,
            result: result,
            details: details
        )
    }

    /// Log sudo command execution
    func logSudoExecution(
        command: String,
        result: AuditResult,
        agentId: UUID?,
        sessionId: UUID?,
        details: [String: String]? = nil
    ) async {
        await log(
            eventType: .sudoExecuted,
            severity: .warning,
            agentId: agentId,
            sessionId: sessionId,
            action: "Sudo executed: \(command)",
            target: nil,
            result: result,
            details: details
        )
    }

    /// Log file access
    func logFileAccess(
        path: String,
        operation: String,
        result: AuditResult,
        agentId: UUID?,
        sessionId: UUID?
    ) async {
        let eventType: AuditEventType
        switch operation.lowercased() {
        case "read":
            eventType = .fileAccessed
        case "write", "modify":
            eventType = .fileModified
        case "delete":
            eventType = .fileDeleted
        default:
            eventType = .fileAccessed
        }

        await log(
            eventType: eventType,
            severity: .info,
            agentId: agentId,
            sessionId: sessionId,
            action: "\(operation) file: \(path)",
            target: path,
            result: result
        )
    }

    /// Log approval granted
    func logApprovalGranted(
        requestId: UUID,
        toolCall: ToolCall,
        agentId: UUID,
        sessionId: UUID,
        justification: String?
    ) async {
        var details: [String: String] = [
            "request_id": requestId.uuidString,
            "tool": toolCall.name
        ]
        if let justification = justification {
            details["justification"] = justification
        }

        await log(
            eventType: .approvalGranted,
            severity: .info,
            agentId: agentId,
            sessionId: sessionId,
            action: "Approved: \(toolCall.name)",
            target: toolCall.arguments["target"],
            result: .success,
            details: details
        )
    }

    /// Log approval denied
    func logApprovalDenied(
        requestId: UUID,
        toolCall: ToolCall,
        agentId: UUID,
        sessionId: UUID,
        justification: String?
    ) async {
        var details: [String: String] = [
            "request_id": requestId.uuidString,
            "tool": toolCall.name
        ]
        if let justification = justification {
            details["justification"] = justification
        }

        await log(
            eventType: .approvalDenied,
            severity: .warning,
            agentId: agentId,
            sessionId: sessionId,
            action: "Denied: \(toolCall.name)",
            target: toolCall.arguments["target"],
            result: .blocked,
            details: details
        )
    }

    /// Log security violation
    func logSecurityViolation(
        violation: String,
        agentId: UUID?,
        sessionId: UUID?,
        details: [String: String]? = nil
    ) async {
        await log(
            eventType: .securityViolation,
            severity: .critical,
            agentId: agentId,
            sessionId: sessionId,
            action: "Security violation: \(violation)",
            target: nil,
            result: .blocked,
            details: details
        )
    }

    /// Log error
    func logError(
        error: Error,
        context: String,
        agentId: UUID?,
        sessionId: UUID?
    ) async {
        await log(
            eventType: .errorOccurred,
            severity: .error,
            agentId: agentId,
            sessionId: sessionId,
            action: "Error in \(context): \(error.localizedDescription)",
            target: nil,
            result: .failure,
            details: ["error_type": String(describing: type(of: error))]
        )
    }

    // MARK: - Core Logging

    private func log(
        eventType: AuditEventType,
        severity: AuditSeverity,
        agentId: UUID?,
        sessionId: UUID?,
        action: String,
        target: String?,
        result: AuditResult,
        details: [String: String]? = nil
    ) async {
        let entry = AuditLog(
            eventType: eventType,
            severity: severity,
            agentId: agentId,
            sessionId: sessionId,
            userId: NSUserName(),
            action: action,
            target: target,
            result: result,
            details: details,
            hostname: Host.current().name
        )

        do {
            try await repository.log(entry)
            logger.info("[\(severity.rawValue.uppercased())] \(action)")
        } catch {
            logger.error("Failed to write audit log: \(error)")
        }
    }

    // MARK: - Query

    /// Query audit logs
    func query(_ query: AuditQuery) async throws -> [AuditLog] {
        try await repository.query(query)
    }

    /// Export audit logs
    func export(_ query: AuditQuery) async throws -> URL {
        try await repository.export(query: query)
    }
}
