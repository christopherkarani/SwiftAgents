# SwiftAgents Playground

A Swift Playground that comes pre-loaded with [SwiftAgents](https://github.com/ChristopherKarani/SwiftAgents), so you can quickly explore the framework and build AI agents interactively.

## Structure

```
SwiftAgentsPlayground.xcworkspace/
├── Package/                    # Wrapper package
│   ├── Package.swift          # References parent SwiftAgents
│   └── Sources/
│       └── SwiftAgentsPlayground/
│           └── SwiftAgentsPlayground.swift  # Re-exports SwiftAgents
├── Playground.playground/      # Interactive playground
│   ├── Contents.swift         # Examples and demos
│   └── contents.xcplayground  # Config (buildActiveScheme=true)
└── contents.xcworkspacedata   # Workspace configuration
```

## Getting Started

1. **Ensure SwiftAgents builds successfully** in the parent directory:
   ```bash
   cd ../..
   swift build
   ```

2. **Open the workspace** in Xcode:
   ```bash
   open SwiftAgentsPlayground.xcworkspace
   ```

3. **Select the Playground** in the left-hand navigator pane.

4. **Build the project** using `⌘ + B` to compile the SwiftAgentsPlayground wrapper package.

5. **Run the playground** by clicking the ▶️ button at the bottom of the editor.

6. **Explore and experiment!** 🚀

## Current Status

⚠️ **Note**: The playground structure is complete and properly configured. However, there are currently some compilation errors in the main SwiftAgents package related to `@Parameter` macro initialization that need to be resolved before the playground can run:

- `SemanticCompactorTool`: Initializer doesn't initialize `text` property
- `WebSearchTool`: Initializer doesn't initialize `query` property  
- `ZoniSearchTool`: Initializer doesn't initialize `query` property

Once these are fixed in the main package, the playground will work seamlessly.

## What's Included

The playground demonstrates:

- 🔧 **Custom Tool Creation** - Build tools for weather, calculations, and more
- 🧠 **Memory Systems** - Maintain conversation context across turns  
- 📊 **Run Hooks** - Monitor agent execution with custom callbacks
- 🛡️ **Input Guardrails** - Validate and filter inputs before processing
- 🔒 **Output Guardrails** - Sanitize responses (e.g., PII redaction)
- ⚙️ **Configuration Presets** - Fast, thorough, and creative agent modes
- 🧪 **Mock Provider** - Test without API calls

## Requirements

- Xcode 15.0+ (with Swift 5.9+)
- macOS 14.0+ (Sonoma)

## Using a Real Provider

Replace the `MockProvider` in the playground with a real inference provider:

```swift
import SwiftAgentsPlayground

let provider = OpenRouterProvider(
    configuration: .init(
        apiKey: "your-api-key",
        model: .claude35Sonnet
    )
)

let agent = ReActAgent.Builder()
    .inferenceProvider(provider)
    .instructions("You are a helpful assistant.")
    .build()
```

## How It Works

This playground uses a **wrapper package** pattern (similar to [PlotPlayground](https://github.com/JohnSundell/PlotPlayground)):

1. The `Package/` directory contains a Swift Package that depends on the parent SwiftAgents package
2. The package re-exports SwiftAgents via `@_exported import SwiftAgents`
3. The playground has `buildActiveScheme='true'` enabled, which tells Xcode to build the package
4. Once built, you can `import SwiftAgentsPlayground` in the playground and use all SwiftAgents features

## Learn More

- [SwiftAgents Documentation](../docs/)
- [API Reference](../README.md)
- [Example Agents](../Sources/SwiftAgents/Examples/)

---

Happy coding! 🎉

