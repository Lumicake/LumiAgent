//
//  AuthorizationManager.swift
//  LumiAgent
//
//  Created by Lumi Agent on 2026-02-18.
//
//  Central security gatekeeper for all operations
//

import Foundation
import Logging

// MARK: - Authorization Manager

/// Manages security, risk assessment, and approval flows
final class AuthorizationManager {
    // MARK: - Singleton

    static let shared = AuthorizationManager()

    // MARK: - Properties

    private let logger = Logger(label: "com.lumiagent.authorization")
    private let auditRepository: AuditRepositoryProtocol
    private let approvalRepository: ApprovalRepositoryProtocol

    // Dangerous commands and patterns
    private let dangerousCommands = [
        "rm -rf /",
        "dd if=/dev/zero",
        ":(){ :|:& };:",  // Fork bomb
        "chmod -R 777",
        "chown -R",
        "mkfs",
        "format",
        "> /dev/sda",
        "mv /* /dev/null"
    ]

    private let sensitivePaths = [
        "/System",
        "/Library",
        "/usr/bin",
        "/usr/sbin",
        "/bin",
        "/sbin",
        "/etc",
        "/var/root"
    ]

    // MARK: - Initialization

    private init() {
        self.auditRepository = AuditRepository()
        self.approvalRepository = ApprovalRepository()
    }

    // MARK: - Risk Assessment

    /// Assess the risk level of a command or operation
    func assessRisk(
        command: String,
        target: String?,
        policy: SecurityPolicy
    ) -> RiskLevel {
        // Check for dangerous commands
        for dangerous in dangerousCommands {
            if command.contains(dangerous) {
                logger.warning("Dangerous command detected: \(command)")
                return .critical
            }
        }

        // Check for sudo
        if command.hasPrefix("sudo ") {
            logger.info("Sudo command detected: \(command)")
            return .high
        }

        // Check for sensitive paths
        if let target = target {
            for sensitivePath in sensitivePaths {
                if target.hasPrefix(sensitivePath) {
                    logger.warning("Sensitive path access: \(target)")
                    return .high
                }
            }
        }

        // Check for deletion operations
        if command.contains("rm ") || command.contains("delete") {
            return .medium
        }

        // Check for file modifications
        if command.contains("mv ") || command.contains("cp ") || command.contains("chmod ") {
            return .medium
        }

        // Check for network operations
        if command.contains("curl ") || command.contains("wget ") || command.contains("nc ") {
            return .low
        }

        // Default to low risk
        return .low
    }

    /// Check if an operation should be auto-approved based on policy
    func shouldAutoApprove(
        riskLevel: RiskLevel,
        policy: SecurityPolicy
    ) -> Bool {
        return riskLevel <= policy.autoApproveThreshold && policy.requireApproval == false
    }

    /// Validate a command against security policy
    func validateCommand(
        _ command: String,
        policy: SecurityPolicy
    ) throws {
        // Check blacklist
        for blacklisted in policy.blacklistedCommands {
            if command.contains(blacklisted) {
                throw AuthorizationError.commandBlacklisted(command)
            }
        }

        // Check if sudo is allowed
        if command.hasPrefix("sudo ") && !policy.allowSudo {
            throw AuthorizationError.sudoNotAllowed
        }

        // If whitelist exists, command must be in it
        if !policy.whitelistedCommands.isEmpty {
            let commandBase = command.components(separatedBy: " ").first ?? ""
            if !policy.whitelistedCommands.contains(where: { command.starts(with: $0) }) {
                throw AuthorizationError.commandNotWhitelisted(commandBase)
            }
        }

        logger.info("Command validated: \(command)")
    }

    // MARK: - Approval Flow

    /// Request approval for an operation
    func requestApproval(
        for toolCall: ToolCall,
        agentId: UUID,
        sessionId: UUID,
        policy: SecurityPolicy
    ) async throws -> ApprovalRequest {
        // Extract command details
        let command = toolCall.arguments["command"] ?? ""
        let target = toolCall.arguments["target"]

        // Assess risk
        let riskLevel = assessRisk(command: command, target: target, policy: policy)

        // Validate command
        try validateCommand(command, policy: policy)

        // Create reasoning
        let reasoning = generateReasoning(
            command: command,
            riskLevel: riskLevel,
            target: target
        )

        // Create approval request
        let request = ApprovalRequest(
            sessionId: sessionId,
            agentId: agentId,
            toolCall: toolCall,
            riskLevel: riskLevel,
            reasoning: reasoning,
            estimatedImpact: generateImpact(command: command, target: target),
            timeout: policy.maxExecutionTime
        )

        // Save to database
        try await approvalRepository.create(request)

        // Log audit event
        await logAudit(
            eventType: .approvalGranted,
            severity: .info,
            agentId: agentId,
            sessionId: sessionId,
            action: "Approval requested for: \(command)",
            target: target,
            result: .success
        )

        logger.info("Approval requested: \(request.id)")
        return request
    }

    /// Approve a request
    func approve(
        requestId: UUID,
        justification: String?,
        modifiedCommand: String?
    ) async throws {
        guard var request = try await approvalRepository.get(id: requestId) else {
            throw AuthorizationError.requestNotFound
        }

        // Check if expired
        if request.isExpired {
            throw AuthorizationError.requestExpired
        }

        // Update request
        request.status = modifiedCommand != nil ? .modified : .approved
        request.userDecision = UserDecision(
            approved: true,
            justification: justification,
            modifiedCommand: modifiedCommand
        )
        request.decidedAt = Date()

        try await approvalRepository.update(request)

        // Log audit event
        await logAudit(
            eventType: .approvalGranted,
            severity: .info,
            agentId: request.agentId,
            sessionId: request.sessionId,
            action: "Approval granted for: \(request.toolCall.name)",
            target: request.toolCall.arguments["target"],
            result: .success
        )

        logger.info("Approval granted: \(requestId)")
    }

    /// Deny a request
    func deny(
        requestId: UUID,
        justification: String?
    ) async throws {
        guard var request = try await approvalRepository.get(id: requestId) else {
            throw AuthorizationError.requestNotFound
        }

        // Update request
        request.status = .denied
        request.userDecision = UserDecision(
            approved: false,
            justification: justification
        )
        request.decidedAt = Date()

        try await approvalRepository.update(request)

        // Log audit event
        await logAudit(
            eventType: .approvalDenied,
            severity: .warning,
            agentId: request.agentId,
            sessionId: request.sessionId,
            action: "Approval denied for: \(request.toolCall.name)",
            target: request.toolCall.arguments["target"],
            result: .blocked
        )

        logger.warning("Approval denied: \(requestId)")
    }

    // MARK: - Audit Logging

    private func logAudit(
        eventType: AuditEventType,
        severity: AuditSeverity,
        agentId: UUID?,
        sessionId: UUID?,
        action: String,
        target: String?,
        result: AuditResult
    ) async {
        let log = AuditLog(
            eventType: eventType,
            severity: severity,
            agentId: agentId,
            sessionId: sessionId,
            userId: NSUserName(),
            action: action,
            target: target,
            result: result,
            hostname: Host.current().name
        )

        do {
            try await auditRepository.log(log)
        } catch {
            logger.error("Failed to log audit event: \(error)")
        }
    }

    // MARK: - Helper Methods

    private func generateReasoning(
        command: String,
        riskLevel: RiskLevel,
        target: String?
    ) -> String {
        switch riskLevel {
        case .low:
            return "This is a low-risk operation that reads or queries data."
        case .medium:
            return "This operation may modify files or system state. Review carefully."
        case .high:
            if command.hasPrefix("sudo ") {
                return "This operation requires elevated privileges. Ensure it's necessary."
            }
            if let target = target, sensitivePaths.contains(where: { target.hasPrefix($0) }) {
                return "This operation accesses sensitive system directories. Proceed with caution."
            }
            return "This is a high-risk operation that could affect system stability."
        case .critical:
            return "⚠️ CRITICAL: This operation could cause data loss or system damage. Verify carefully."
        }
    }

    private func generateImpact(
        command: String,
        target: String?
    ) -> String {
        if command.contains("rm ") {
            return "Files will be permanently deleted"
        }
        if command.contains("chmod ") || command.contains("chown ") {
            return "File permissions will be modified"
        }
        if command.hasPrefix("sudo ") {
            return "System-level changes may occur"
        }
        if let target = target {
            return "Target: \(target)"
        }
        return "Operation will be executed with current user permissions"
    }
}

// MARK: - Authorization Error

enum AuthorizationError: Error, LocalizedError {
    case commandBlacklisted(String)
    case commandNotWhitelisted(String)
    case sudoNotAllowed
    case requestNotFound
    case requestExpired
    case insufficientPrivileges

    var errorDescription: String? {
        switch self {
        case .commandBlacklisted(let cmd):
            return "Command '\(cmd)' is blacklisted for security reasons"
        case .commandNotWhitelisted(let cmd):
            return "Command '\(cmd)' is not in the whitelist"
        case .sudoNotAllowed:
            return "Sudo commands are not allowed by the current security policy"
        case .requestNotFound:
            return "Approval request not found"
        case .requestExpired:
            return "Approval request has expired"
        case .insufficientPrivileges:
            return "Insufficient privileges to perform this operation"
        }
    }
}
