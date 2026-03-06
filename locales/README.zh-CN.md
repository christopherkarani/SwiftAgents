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

**Swarm 是一个专为现代 Swift 生态系统打造的高性能、类型安全的智能体编排框架。** 它提供了一套统一的抽象，用于将 LLM、工具和记忆整合到生产级工作流中，具备编译时安全性、容错运行以及对 Apple Foundation Models 的原生支持。

### 核心特性
- **类型安全工具**: 使用 `@Tool` 宏定义工具，自动生成 JSON schema 并进行编译时验证。
- **严格并发性**: 为 Swift 6 从零构建，确保所有智能体交互的数据竞争安全。
- **弹性工作流**: 利用 Hive 驱动的检查点功能，实现自动崩溃恢复的持久执行状态。
- **统一记忆系统**: 可插拔的记忆系统，包括 SIMD 加速的向量记忆。
- **通用模型支持**: 在端侧 Foundation Models、Anthropic、OpenAI、Ollama 和 MLX 之间无缝切换。

---

### 快速开始

```swift
import Swarm

@Tool("获取指定地点的当前天气")
struct WeatherTool {
    @Parameter("城市和省份，例如：上海市") 
    var location: String

    func execute() async throws -> String {
        "上海今天晴，气温 22°C"
    }
}

let analyst = Agent(
    name: "WeatherAnalyst",
    tools: [WeatherTool()],
    instructions: "请提供简洁的天气报告。"
)

let result = try await analyst.run("上海的天气怎么样？")
print(result.output)
```

---

### 安装
在您的 `Package.swift` 中添加 Swarm：

```swift
.package(url: "https://github.com/christopherkarani/Swarm.git", from: "2.0.0")
```

---

### 许可证
Swarm 采用 [MIT 许可证](../LICENSE) 开源。
