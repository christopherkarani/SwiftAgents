// ConduitProviderType.swift
// SwiftAgents Framework
//
// Represents the different backend providers available through Conduit.

import Conduit
import Foundation

// MARK: - ConduitProviderType

/// Represents the different backend providers available through Conduit.
///
/// Each case stores the model identifier and any required credentials for that
/// provider. The model is passed per-request to `generate()`, not stored on the
/// provider instance.
///
/// Example:
/// ```swift
/// // Local MLX inference on Apple Silicon
/// let mlxProvider = ConduitProviderType.mlx(model: .llama3_2_1B)
///
/// // Cloud inference via Anthropic
/// let anthropicProvider = ConduitProviderType.anthropic(
///     model: .claudeSonnet45,
///     apiKey: "your-api-key"
/// )
///
/// // HuggingFace inference
/// let hfProvider = ConduitProviderType.huggingFace(
///     model: .huggingFace("meta-llama/Llama-3.1-8B-Instruct"),
///     token: "your-hf-token"
/// )
/// ```
public enum ConduitProviderType: Sendable {
    // MARK: - Provider Cases

    /// Local MLX inference on Apple Silicon devices.
    ///
    /// Offers zero network traffic and complete privacy. Requires Metal GPU.
    /// Models run entirely on-device.
    ///
    /// - Parameter model: The MLX model identifier to use.
    case mlx(model: ModelIdentifier)

    /// Anthropic Claude API provider.
    ///
    /// Supports advanced capabilities including vision and extended thinking.
    /// Requires a valid Anthropic API key.
    ///
    /// - Parameters:
    ///   - model: The Anthropic model identifier (e.g., `.claudeSonnet45`).
    ///   - apiKey: The Anthropic API key for authentication.
    case anthropic(model: AnthropicModelID, apiKey: String)

    /// OpenAI API provider.
    ///
    /// Supports GPT models with function calling capabilities.
    ///
    /// - Parameters:
    ///   - model: The OpenAI model identifier (e.g., `.gpt4o`).
    ///   - apiKey: The OpenAI API key for authentication.
    case openAI(model: OpenAIModelID, apiKey: String)

    /// HuggingFace Inference API provider.
    ///
    /// Provides access to hundreds of models via HuggingFace's cloud infrastructure.
    ///
    /// - Parameters:
    ///   - model: The HuggingFace model identifier.
    ///   - token: The HuggingFace API token for authentication.
    case huggingFace(model: ModelIdentifier, token: String)

    /// Apple Foundation Models provider (iOS 26+).
    ///
    /// System-integrated on-device AI managed by the OS. Zero setup required.
    /// Only available on iOS 26+ devices with Apple Silicon.
    case foundationModels

    // MARK: - Computed Properties

    /// The model identifier associated with this provider type.
    ///
    /// For `foundationModels`, this returns the `.foundationModels` model ID.
    /// This returns a string representation of the model.
    public var modelString: String {
        switch self {
        case let .mlx(model):
            return model.rawValue
        case let .anthropic(model, _):
            return model.rawValue
        case let .openAI(model, _):
            return model.rawValue
        case let .huggingFace(model, _):
            return model.rawValue
        case .foundationModels:
            return ModelIdentifier.foundationModels.rawValue
        }
    }

    /// A human-readable display name for the provider.
    ///
    /// Useful for logging, debugging, and UI display.
    public var displayName: String {
        switch self {
        case .mlx:
            return "MLX (Local)"
        case .anthropic:
            return "Anthropic"
        case .openAI:
            return "OpenAI"
        case .huggingFace:
            return "HuggingFace"
        case .foundationModels:
            return "Apple Foundation Models"
        }
    }

    /// Indicates whether this provider requires network access.
    ///
    /// Returns `false` for local providers (MLX, Foundation Models),
    /// `true` for cloud providers (Anthropic, OpenAI, HuggingFace).
    public var requiresNetwork: Bool {
        switch self {
        case .mlx, .foundationModels:
            return false
        case .anthropic, .openAI, .huggingFace:
            return true
        }
    }

    /// Indicates whether this provider runs on-device.
    ///
    /// On-device providers offer privacy benefits and work offline.
    public var isOnDevice: Bool {
        !requiresNetwork
    }
}

// MARK: - Equatable

extension ConduitProviderType: Equatable {
    public static func == (lhs: ConduitProviderType, rhs: ConduitProviderType) -> Bool {
        switch (lhs, rhs) {
        case let (.mlx(lhsModel), .mlx(rhsModel)):
            return lhsModel == rhsModel
        case let (.anthropic(lhsModel, lhsKey), .anthropic(rhsModel, rhsKey)):
            return lhsModel == rhsModel && lhsKey == rhsKey
        case let (.openAI(lhsModel, lhsKey), .openAI(rhsModel, rhsKey)):
            return lhsModel == rhsModel && lhsKey == rhsKey
        case let (.huggingFace(lhsModel, lhsToken), .huggingFace(rhsModel, rhsToken)):
            return lhsModel == rhsModel && lhsToken == rhsToken
        case (.foundationModels, .foundationModels):
            return true
        default:
            return false
        }
    }
}

// MARK: - CustomStringConvertible

extension ConduitProviderType: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .mlx(model):
            return "ConduitProviderType.mlx(\(model))"
        case let .anthropic(model, _):
            return "ConduitProviderType.anthropic(\(model))"
        case let .openAI(model, _):
            return "ConduitProviderType.openAI(\(model))"
        case let .huggingFace(model, _):
            return "ConduitProviderType.huggingFace(\(model))"
        case .foundationModels:
            return "ConduitProviderType.foundationModels"
        }
    }
}

// MARK: - CustomDebugStringConvertible

extension ConduitProviderType: CustomDebugStringConvertible {
    public var debugDescription: String {
        description
    }
}
