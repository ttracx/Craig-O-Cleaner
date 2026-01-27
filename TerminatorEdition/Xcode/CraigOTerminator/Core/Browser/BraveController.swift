//
//  BraveController.swift
//  CraigOTerminator
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import Foundation

// MARK: - Brave Controller

/// Controller for Brave Browser automation
final class BraveController: ChromiumController {
    init() {
        super.init(app: .brave)
    }
}
