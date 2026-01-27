//
//  EdgeController.swift
//  CraigOTerminator
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import Foundation

// MARK: - Edge Controller

/// Controller for Microsoft Edge browser automation
final class EdgeController: ChromiumController {
    init() {
        super.init(app: .edge)
    }
}
