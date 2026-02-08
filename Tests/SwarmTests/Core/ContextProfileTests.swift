// ContextProfileTests.swift
// SwarmTests
//
// Tests for ContextProfile presets and budgeting behavior.

import Foundation
@testable import Swarm
import Testing

@Suite("ContextProfile Preset Tests")
struct ContextProfilePresetTests {
    @Test("Presets define stable ratio ordering")
    func presetRatioOrdering() {
        let lite = ContextProfile.lite
        let balanced = ContextProfile.balanced
        let heavy = ContextProfile.heavy

        #expect(lite.workingTokenRatio < balanced.workingTokenRatio)
        #expect(balanced.workingTokenRatio < heavy.workingTokenRatio)

        #expect(lite.memoryTokenRatio > balanced.memoryTokenRatio)
        #expect(balanced.memoryTokenRatio > heavy.memoryTokenRatio)

        #expect(lite.toolIOTokenRatio == balanced.toolIOTokenRatio)
        #expect(balanced.toolIOTokenRatio == heavy.toolIOTokenRatio)

        #expect(lite.summaryTokenRatio > balanced.summaryTokenRatio)
        #expect(balanced.summaryTokenRatio > heavy.summaryTokenRatio)
    }

    @Test("Preset ratios sum to 1.0")
    func presetRatioSum() {
        let presets = [ContextProfile.lite, ContextProfile.balanced, ContextProfile.heavy]
        for preset in presets {
            let sum = preset.workingTokenRatio + preset.memoryTokenRatio + preset.toolIOTokenRatio
            #expect(abs(sum - 1.0) < 0.0001)
        }
    }
}

@Suite("ContextProfile Budget Tests")
struct ContextProfileBudgetTests {
    @Test("Budget splits follow ratios for lite preset")
    func budgetSplitsLite() {
        let profile = ContextProfile.lite(maxContextTokens: 4000)
        let budget = profile.budget

        #expect(budget.maxContextTokens == 4000)
        #expect(budget.workingTokens == 2000)
        #expect(budget.memoryTokens == 1400)
        #expect(budget.toolIOTokens == 600)
        #expect(budget.workingTokens + budget.memoryTokens + budget.toolIOTokens == 4000)
        #expect(profile.memoryTokenLimit == 1400)
        #expect(profile.summaryTokenLimit == 840)
    }

    @Test("Budget splits follow ratios for balanced preset")
    func budgetSplitsBalanced() {
        let profile = ContextProfile.balanced(maxContextTokens: 4000)
        let budget = profile.budget

        #expect(budget.workingTokens == 2200)
        #expect(budget.memoryTokens == 1200)
        #expect(budget.toolIOTokens == 600)
        #expect(profile.summaryTokenLimit == 600)
    }

    @Test("Budget splits follow ratios for heavy preset")
    func budgetSplitsHeavy() {
        let profile = ContextProfile.heavy(maxContextTokens: 4000)
        let budget = profile.budget

        #expect(budget.workingTokens == 2400)
        #expect(budget.memoryTokens == 1000)
        #expect(budget.toolIOTokens == 600)
        #expect(profile.summaryTokenLimit == 400)
    }
}

@Suite("ContextProfile Platform Defaults")
struct ContextProfilePlatformDefaultsTests {
    @Test("Platform defaults expose expected max context tokens")
    func platformDefaultTokens() {
        #if os(macOS)
        #expect(ContextProfile.platformDefault.maxContextTokens == ContextProfile.PlatformDefaults.macOS.maxContextTokens)
        #else
        #expect(ContextProfile.platformDefault.maxContextTokens == ContextProfile.PlatformDefaults.iOS.maxContextTokens)
        #endif
    }

    @Test("macOS default context tokens >= iOS default")
    func platformDefaultOrdering() {
        #expect(ContextProfile.PlatformDefaults.macOS.maxContextTokens >= ContextProfile.PlatformDefaults.iOS.maxContextTokens)
    }
}
