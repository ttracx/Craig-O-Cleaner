//
//  ChromeController.swift
//  CraigOTerminator
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import Foundation

// MARK: - Chrome Controller

/// Controller for Google Chrome browser automation
final class ChromeController: ChromiumController {
    init() {
        super.init(app: .chrome)
    }
}
