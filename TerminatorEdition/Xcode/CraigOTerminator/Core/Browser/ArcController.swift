//
//  ArcController.swift
//  CraigOTerminator
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import Foundation

// MARK: - Arc Controller

/// Controller for Arc browser automation
final class ArcController: ChromiumController {
    init() {
        super.init(app: .arc)
    }
}
