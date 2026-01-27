// MARK: - WorkflowSchema.swift
// Craig-O-Clean - AI Workflow Schema
// Defines the strict JSON schema for AI-generated plans

import Foundation

/// Schema definition for validating AI workflow responses
enum WorkflowSchema {

    /// JSON Schema for the AI plan response
    static let planSchema: [String: Any] = [
        "type": "object",
        "required": ["title", "description", "steps"],
        "properties": [
            "title": [
                "type": "string",
                "minLength": 1,
                "maxLength": 100
            ],
            "description": [
                "type": "string",
                "minLength": 1,
                "maxLength": 500
            ],
            "steps": [
                "type": "array",
                "minItems": 1,
                "maxItems": 10,
                "items": [
                    "type": "object",
                    "required": ["capabilityId", "reason", "requiresApproval"],
                    "properties": [
                        "capabilityId": [
                            "type": "string",
                            "pattern": "^[a-z]+\\.[a-z_]+.*$"
                        ],
                        "reason": [
                            "type": "string",
                            "minLength": 1
                        ],
                        "args": [
                            "type": "object",
                            "additionalProperties": [
                                "type": "string"
                            ]
                        ],
                        "requiresApproval": [
                            "type": "boolean"
                        ]
                    ]
                ]
            ]
        ]
    ]

    /// Validate a plan JSON dictionary against the schema (basic validation)
    static func validate(_ json: [String: Any]) -> [String] {
        var errors: [String] = []

        guard let title = json["title"] as? String, !title.isEmpty else {
            errors.append("Missing or empty 'title'")
            return errors
        }

        guard let description = json["description"] as? String, !description.isEmpty else {
            errors.append("Missing or empty 'description'")
            return errors
        }

        guard let steps = json["steps"] as? [[String: Any]], !steps.isEmpty else {
            errors.append("Missing or empty 'steps' array")
            return errors
        }

        if steps.count > 10 {
            errors.append("Too many steps (max 10)")
        }

        for (i, step) in steps.enumerated() {
            guard let capId = step["capabilityId"] as? String, !capId.isEmpty else {
                errors.append("Step \(i): missing capabilityId")
                continue
            }

            guard let _ = step["reason"] as? String else {
                errors.append("Step \(i): missing reason")
                continue
            }

            if step["requiresApproval"] as? Bool == nil {
                errors.append("Step \(i): missing requiresApproval")
            }
        }

        return errors
    }
}
