# Ficha técnica — Integración módulo generativo (Ollama, LangChain)

| Campo | Detalle |
|---|---|
| Identificador del módulo | M5 |
| Nombre del módulo | Integración módulo generativo (Ollama, LangChain) |
| Propósito del componente | Orquestar prompts y recuperación de contexto para respuestas generativas del asistente. |
| Entradas esperadas | Prompt del usuario, contexto (RAG), parámetros de generación. |
| Salidas esperadas | Respuestas generadas, trazas de razonamiento y uso de herramientas. |
| Herramientas y entorno | Ollama, LangChain, Python 3.x; dependencias en `chat/requirements.txt`. |
| Código relevante / enlaces | `chat/agents/ollama_agent.py`, `chat/agents/ollama_retriever.py`, `chat/main.py`, `chat/prompts/system_prompt.py`, `chat/tools/`. |
| Capturas / ejemplos | Transcripciones de sesiones y ejemplos de prompts/respuestas. |
| Resultados (pruebas) | Métricas de calidad (p. ej., exactitud factual), latencia y uso de memoria. |
| Observaciones y sugerencias | Gestionar tiempo de respuesta y límites de contexto; logging estructurado y evaluación continua. |

## Notas
- Incluir configuración de modelos (Ollama) y credenciales si aplicase (en `.env`).
