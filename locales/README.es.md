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

**Swarm es un marco de orquestación de agentes de alto rendimiento y tipo seguro, diseñado para el ecosistema Swift moderno.** Proporciona una abstracción unificada para encadenar LLMs, herramientas y memoria en flujos de trabajo listos para producción con seguridad en tiempo de compilación y soporte nativo para los modelos de Apple.

### Características Clave
- **Herramientas de Tipo Seguro**: Defina herramientas usando la macro `@Tool` con generación automática de esquemas JSON.
- **Concurrencia Estricta**: Construido desde cero para Swift 6, garantizando la seguridad contra carreras de datos.
- **Flujos de Trabajo Resilientes**: Estado de ejecución persistente con puntos de control impulsados por Hive.
- **Memoria Unificada**: Sistemas de memoria conectables que incluyen memoria vectorial acelerada por SIMD.
- **Soporte Universal**: Cambie sin problemas entre modelos locales de Apple, Anthropic, OpenAI, Ollama y MLX.

---

### Inicio Rápido

```swift
import Swarm

@Tool("Obtiene el clima actual para una ubicación")
struct WeatherTool {
    @Parameter("La ciudad y el estado, ej. Madrid, ES") 
    var location: String

    func execute() async throws -> String {
        "Soleado, 22°C en \(location)"
    }
}

let analyst = Agent(
    name: "WeatherAnalyst",
    tools: [WeatherTool()],
    instructions: "Proporciona informes meteorológicos concisos."
)

let result = try await analyst.run("¿Cómo está el clima en Madrid?")
print(result.output)
```

---

### Instalación
Añada Swarm a su `Package.swift`:

```swift
.package(url: "https://github.com/christopherkarani/Swarm.git", from: "2.0.0")
```

---

### Licencia
Swarm se publica bajo la [Licencia MIT](../LICENSE).
