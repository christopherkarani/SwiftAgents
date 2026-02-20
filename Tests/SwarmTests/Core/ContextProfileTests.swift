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

    @Test("Invalid values are normalized to non-crashing safe values")
    func invalidValuesAreNormalized() {
        let profile = ContextProfile(
            preset: .balanced,
            maxContextTokens: 0,
            workingTokenRatio: 2.0,
            memoryTokenRatio: -1.0,
            toolIOTokenRatio: 0.0,
            summaryTokenRatio: 2.0,
            maxToolOutputTokens: 0,
            maxRetrievedItems: 0,
            maxRetrievedItemTokens: 0,
            summaryCadenceTurns: 0,
            summaryTriggerUtilization: -1.0
        )

        let ratioSum = profile.workingTokenRatio + profile.memoryTokenRatio + profile.toolIOTokenRatio
        #expect(abs(ratioSum - 1.0) < 0.0001)
        #expect(profile.maxContextTokens == 1)
        #expect(profile.maxToolOutputTokens == 1)
        #expect(profile.maxRetrievedItems == 1)
        #expect(profile.maxRetrievedItemTokens == 1)
        #expect(profile.summaryCadenceTurns == 1)
        #expect(profile.summaryTokenRatio == 1.0)
        #expect(profile.summaryTriggerUtilization == 0.0)

        // Minimum ratio floor ensures all budgets remain usable after clamping
        // extreme inputs. Even with workingRatio=2.0 and memoryRatio=-1.0, no
        // ratio should collapse to zero, preventing broken callers.
        #expect(profile.workingTokenRatio > 0)
        #expect(profile.memoryTokenRatio > 0)
        #expect(profile.toolIOTokenRatio > 0)
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

@Suite("ContextProfile strict4k")
struct ContextProfileStrict4kTests {
    @Test("strict4k exposes 4096 total context envelope and 3412 max input")
    func strict4kDefaults() {
        let profile = ContextProfile.strict4k
        let budget = profile.budget

        #expect(profile.preset == .strict4k)
        #expect(budget.maxTotalContextTokens == 4096)
        #expect(budget.maxInputTokens == 3412)
        #expect(budget.maxOutputTokens == 500)
        #expect(budget.outputReserveTokens == 500)
        #expect(budget.protocolOverheadReserveTokens == 120)
        #expect(budget.safetyMarginTokens == 64)
        #expect(profile.maxContextTokens == 3412)
        #expect(profile.maxTotalContextTokens == 4096)
        #expect(budget.workingTokens == 1912)
        #expect(budget.memoryTokens == 900)
        #expect(budget.toolIOTokens == 600)
        #expect(budget.workingTokens + budget.memoryTokens + budget.toolIOTokens == budget.maxInputTokens)
        #expect(profile.memoryTokenLimit == 900)
        #expect(profile.summaryTokenLimit == 450)
        #expect(budget.bucketCaps?.system == 512)
        #expect(budget.bucketCaps?.history == 1400)
        #expect(budget.bucketCaps?.memory == 900)
        #expect(budget.bucketCaps?.toolIO == 600)
    }

    @Test("strict4k template overrides are honored")
    func strict4kTemplateOverrides() {
        let template = ContextProfile.Strict4kTemplate(
            systemTokens: 600,
            historyTokens: 1200,
            memoryTokens: 900,
            toolIOTokens: 500,
            outputReserveTokens: 600,
            protocolOverheadReserveTokens: 100,
            safetyMarginTokens: 100
        )
        let profile = ContextProfile.strict4k(template: template)
        let budget = profile.budget

        #expect(budget.maxTotalContextTokens == 4096)
        #expect(budget.maxInputTokens == 3296)
        #expect(budget.maxOutputTokens == 600)
        #expect(budget.workingTokens == 1896)
        #expect(budget.memoryTokens == 900)
        #expect(budget.toolIOTokens == 500)
        #expect(budget.workingTokens + budget.memoryTokens + budget.toolIOTokens == budget.maxInputTokens)
        #expect(profile.memoryTokenLimit == 900)
        #expect(profile.summaryTokenLimit == 450)
        #expect(budget.bucketCaps?.system == 600)
        #expect(budget.bucketCaps?.history == 1200)
        #expect(budget.bucketCaps?.memory == 900)
        #expect(budget.bucketCaps?.toolIO == 500)
    }
}
