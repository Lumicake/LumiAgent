//
//  AuditLog.swift
//  LumiAgent
//
//  Created by Lumi Agent on 2026-02-18.
//

import Foundation

// MARK: - Audit Log

/// Immutable audit log entry for security and compliance
struct AuditLog: Identifiable, Codable {
    let id: UUID
    let eventType: AuditEventType
    let severity: AuditSeverity
    let timestamp: Date
    let agentId: UUID?
    let sessionId: UUID?
    let userId: String? // System username
    let action: String
    let target: String?
    let result: AuditResult
    let details: [String: String]?
    let ipAddress: String?
    let hostname: String?

    init(
        id: UUID = UUID(),
        eventType: AuditEventType,
        severity: AuditSeverity,
        timestamp: Date = Date(),
        agentId: UUID? = nil,
        sessionId: UUID? = nil,
        userId: String? = nil,
        action: String,
        target: String? = nil,
        result: AuditResult,
        details: [String: String]? = nil,
        ipAddress: String? = nil,
        hostname: String? = nil
    ) {
        self.id = id
        self.eventType = eventType
        self.severity = severity
        self.timestamp = timestamp
        self.agentId = agentId
        self.sessionId = sessionId
        self.userId = userId
        self.action = action
        self.target = target
        self.result = result
        self.details = details
        self.ipAddress = ipAddress
        self.hostname = hostname
    }
}

// MARK: - Audit Event Type

/// Types of audit events
enum AuditEventType: String, Codable, CaseIterable {
    case commandExecuted = "command_executed"
    case fileAccessed = "file_accessed"
    case fileModified = "file_modified"
    case fileDeleted = "file_deleted"
    case approvalGranted = "approval_granted"
    case approvalDenied = "approval_denied"
    case approvalExpired = "approval_expired"
    case sudoExecuted = "sudo_executed"
    case networkRequest = "network_request"
    case databaseQuery = "database_query"
    case authenticationAttempt = "authentication_attempt"
    case configurationChanged = "configuration_changed"
    case errorOccurred = "error_occurred"
    case securityViolation = "security_violation"

    var displayName: String {
        switch self {
        case .commandExecuted: return "Command Executed"
        case .fileAccessed: return "File Accessed"
        case .fileModified: return "File Modified"
        case .fileDeleted: return "File Deleted"
        case .approvalGranted: return "Approval Granted"
        case .approvalDenied: return "Approval Denied"
        case .approvalExpired: return "Approval Expired"
        case .sudoExecuted: return "Sudo Command Executed"
        case .networkRequest: return "Network Request"
        case .databaseQuery: return "Database Query"
        case .authenticationAttempt: return "Authentication Attempt"
        case .configurationChanged: return "Configuration Changed"
        case .errorOccurred: return "Error Occurred"
        case .securityViolation: return "Security Violation"
        }
    }

    var icon: String {
        switch self {
        case .commandExecuted: return "terminal"
        case .fileAccessed: return "doc.text"
        case .fileModified: return "pencil.line"
        case .fileDeleted: return "trash"
        case .approvalGranted: return "checkmark.shield"
        case .approvalDenied: return "xmark.shield"
        case .approvalExpired: return "clock.badge.xmark"
        case .sudoExecuted: return "key.fill"
        case .networkRequest: return "network"
        case .databaseQuery: return "cylinder"
        case .authenticationAttempt: return "lock"
        case .configurationChanged: return "gear"
        case .errorOccurred: return "exclamationmark.triangle"
        case .securityViolation: return "shield.slash"
        }
    }
}

// MARK: - Audit Severity

/// Severity level for audit events
enum AuditSeverity: String, Codable, Comparable {
    case info
    case warning
    case error
    case critical

    static func < (lhs: AuditSeverity, rhs: AuditSeverity) -> Bool {
        let order: [AuditSeverity] = [.info, .warning, .error, .critical]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }

    var displayName: String {
        rawValue.capitalized
    }

    var color: String {
        switch self {
        case .info: return "blue"
        case .warning: return "yellow"
        case .error: return "orange"
        case .critical: return "red"
        }
    }
}

// MARK: - Audit Result

/// Result of an audited action
enum AuditResult: String, Codable {
    case success
    case failure
    case blocked
    case partial

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .success: return "checkmark.circle"
        case .failure: return "xmark.circle"
        case .blocked: return "hand.raised.slash"
        case .partial: return "exclamationmark.circle"
        }
    }
}

// MARK: - Audit Query

/// Query parameters for filtering audit logs
struct AuditQuery {
    var startDate: Date?
    var endDate: Date?
    var eventTypes: [AuditEventType]?
    var severities: [AuditSeverity]?
    var agentIds: [UUID]?
    var sessionIds: [UUID]?
    var searchText: String?
    var limit: Int?
    var offset: Int?

    init(
        startDate: Date? = nil,
        endDate: Date? = nil,
        eventTypes: [AuditEventType]? = nil,
        severities: [AuditSeverity]? = nil,
        agentIds: [UUID]? = nil,
        sessionIds: [UUID]? = nil,
        searchText: String? = nil,
        limit: Int? = 100,
        offset: Int? = 0
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.eventTypes = eventTypes
        self.severities = severities
        self.agentIds = agentIds
        self.sessionIds = sessionIds
        self.searchText = searchText
        self.limit = limit
        self.offset = offset
    }
}
