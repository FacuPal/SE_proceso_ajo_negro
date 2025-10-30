# Ficha técnica — Base orientada a grafos (Neo4j)

| Campo | Detalle |
|---|---|
| Identificador del módulo | M4 |
| Nombre del módulo | Base orientada a grafos (Neo4j) |
| Propósito del componente | Persistir el conocimiento estructurado como grafo; habilitar consultas y análisis de relaciones. |
| Entradas esperadas | Scripts Cypher, cargas iniciales, actualizaciones de nodos y relaciones. |
| Salidas esperadas | Respuestas a consultas (paths, agregaciones), subgrafos para análisis. |
| Herramientas y entorno | Neo4j, Cypher; integración Python vía `neo4j` driver; configuración en entorno local/remote. |
| Código relevante / enlaces | `db/db-model.cypher`, `db/casos_prueba.cypher`, `p1.cypher`; utilidades: `chat/utils/run_cypher.py`. |
| Capturas / ejemplos | Capturas de Neo4j Browser y consultas típicas. |
| Resultados (pruebas) | Ejecución de `casos_prueba.cypher`; tiempos de consulta; consistencia del modelo. |
| Observaciones y sugerencias | Versionar cambios en el esquema; incluir índices/constraints; cargar datos de prueba reproducibles. |

## Notas
- Documentar credenciales/URI de conexión en un `.env` (no versionado).
