<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../docs/assets/banner-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="../docs/assets/banner-light.svg">
    <img alt="Swarm — Swift Agent Framework" src="../docs/assets/banner-dark.svg" width="800">
  </picture>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Swift-6.2-orange.svg" alt="Swift 6.2">
  <img src="https://img.shields.io/badge/Platforms-iOS%20|%20macOS%20|%20Linux-blue.svg" alt="Platforms">
  <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License">
</p>

<p align="center">
  <a href="../README.md">English</a> | 
  <a href="README.es.md">Español</a> | 
  <a href="README.ja.md">日本語</a> | 
  <a href="README.zh-CN.md">中文</a>
</p>

---

**Swarm は、モダンな Swift エコシステム向けに構築された、高性能で型安全なエージェント・オーケストレーション・フレームワークです。** LLM、ツール、メモリを本番環境レベルのワークフローに統合するための統一された抽象化を提供し、コンパイル時の安全性、クラッシュ耐性のある実行、および Apple Foundation Models のネイティブサポートを実現します。

### 主な特徴
- **型安全なツール**: `@Tool` マクロを使用して、自動 JSON スキーマ生成とコンパイル時の検証を備えたツールを定義。
- **厳密な並行性**: Swift 6 のためにゼロから構築され、すべてのエージェント対話におけるデータ競合の安全性を保証。
- **レジリエントなワークフロー**: Hive を利用したチェックポイント機能による、自動クラッシュ復旧可能な永続的な実行状態。
- **統合メモリ**: SIMD 加速されたベクトルメモリを含む、プラグ可能なメモリシステム。
- **ユニバーサル・プロバイダー・サポート**: オンデバイスの Foundation Models、Anthropic、OpenAI、Ollama、MLX をシームレスに切り替え。

---

### クイックスタート

```swift
import Swarm

@Tool("指定された場所の現在の天気を取得します")
struct WeatherTool {
    @Parameter("市区町村、例：東京都千代田区") 
    var location: String

    func execute() async throws -> String {
        "\(location)は晴れ、気温は22°Cです"
    }
}

let analyst = Agent(
    name: "WeatherAnalyst",
    tools: [WeatherTool()],
    instructions: "簡潔な天気予報を提供してください。"
)

let result = try await analyst.run("東京の天気はどうですか？")
print(result.output)
```

---

### インストール
`Package.swift` に Swarm を追加してください：

```swift
.package(url: "https://github.com/christopherkarani/Swarm.git", from: "2.0.0")
```

---

### ライセンス
Swarm は [MIT ライセンス](../LICENSE)の下で公開されています。
