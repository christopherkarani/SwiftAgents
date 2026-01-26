# Pull Request

## Thank you for contributing to SwiftAgents! 🎉

We appreciate your effort to improve the framework. This template helps ensure high-quality contributions that align with the project's standards.

---

## Description

### What does this PR do?
<!-- Provide a clear and concise description of your changes -->


### Motivation and Context
<!-- Why is this change needed? What problem does it solve? -->
<!-- If it fixes an open issue, please link to the issue here using #issue_number -->

Fixes # (issue)

---

## Type of Change

Please check the relevant option(s):

- [ ] 🐛 **Bug fix** (non-breaking change which fixes an issue)
- [ ] ✨ **New feature** (non-breaking change which adds functionality)
- [ ] 🔨 **Refactoring** (code improvement without functional changes)
- [ ] 📚 **Documentation** (updates to README, inline docs, or examples)
- [ ] ⚠️ **Breaking change** (fix or feature that would cause existing functionality to not work as expected)
- [ ] 🧪 **Test improvement** (adding missing tests or improving existing ones)
- [ ] 🔧 **Build/CI** (changes to build process, dependencies, or CI configuration)

---

## Changes Made

### Implementation Details
<!-- Describe the technical implementation. Include architectural decisions, design patterns used, and reasoning behind your approach -->


### Files Changed
<!-- List the main files modified and briefly explain why -->

- `path/to/file.swift` - Description of changes
- `path/to/another/file.swift` - Description of changes

### API Changes (if applicable)
<!-- Describe any new public APIs, protocol changes, or modifications to existing interfaces -->


---

## Testing

### Test Coverage
<!-- Describe the tests you added or modified to cover your changes -->

- [ ] I have followed **Test-Driven Development (TDD)** practices (wrote tests first, then implementation)
- [ ] All new code is covered by unit tests
- [ ] I have added tests for edge cases and error conditions
- [ ] I have used mock protocols for external dependencies (LLM providers, network, etc.)

### Test Results
```bash
# Paste the output of: swift test
```

### Manual Testing
<!-- If applicable, describe any manual testing performed -->


---

## Breaking Changes

<!-- If this PR introduces breaking changes, describe them here and provide migration guidance -->

**Does this PR introduce breaking changes?**
- [ ] Yes (please describe below)
- [ ] No

### Breaking Change Details
<!-- If yes, describe what breaks and how users should migrate -->


---

## Pre-Submission Checklist

### Code Quality
- [ ] My code follows the Swift 6.2 standards and project conventions
- [ ] I have performed a self-review of my own code
- [ ] I have run `swift build` and ensured no compilation errors
- [ ] I have run `swift test` and all tests pass
- [ ] I have run SwiftFormat: `swift package plugin --allow-writing-to-package-directory swiftformat`
- [ ] I have run SwiftLint and fixed any warnings: `swiftlint lint`

### Concurrency & Safety
- [ ] All public types conform to `Sendable` where appropriate
- [ ] I have used `async/await` and structured concurrency correctly
- [ ] I have properly applied `@MainActor`, `actor`, or `nonisolated` annotations
- [ ] My code is free from data races and concurrency issues

### Documentation
- [ ] I have added/updated documentation comments for public APIs
- [ ] I have updated the README.md if needed
- [ ] I have added examples to `Sources/SwiftAgents/Examples/` if introducing new features
- [ ] My code does not use `print()` statements (uses `swift-log` instead)

### Testing (TDD Required)
- [ ] I wrote tests **before** writing the implementation (Red phase)
- [ ] I wrote minimal code to make tests pass (Green phase)
- [ ] I refactored while keeping tests green (Refactor phase)
- [ ] Mock protocols are used for external dependencies

### Version Compatibility
- [ ] My code supports the minimum requirements: iOS 17+, macOS 14+, Swift 6.2
- [ ] I have not introduced dependencies that break compatibility

---

## Additional Context

### Screenshots (if applicable)
<!-- Add screenshots or screen recordings for UI changes or examples -->


### Related Issues/PRs
<!-- Link to related issues or pull requests -->

- Related to #
- Depends on #
- Blocks #

### Questions or Concerns
<!-- Any questions for reviewers or areas you'd like specific feedback on? -->


---

## Reviewer Checklist (for maintainers)

- [ ] Code follows project architecture and patterns
- [ ] Tests are comprehensive and follow TDD principles
- [ ] Documentation is clear and complete
- [ ] No security vulnerabilities introduced (SQL injection, XSS, command injection, etc.)
- [ ] Performance implications are acceptable
- [ ] Breaking changes are properly documented
- [ ] CI/CD checks pass

---

**Thank you again for your contribution!** Your efforts help make SwiftAgents better for the entire Swift community. If you have any questions, feel free to ask in the comments below.
