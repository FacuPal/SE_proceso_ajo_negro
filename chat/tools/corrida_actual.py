from utils.run_cypher import run_cypher
from langchain_core.tools import tool

# ============================================================================
# TOOL 3: Completar Datos del Candidato
# ============================================================================
# Permite agregar una nueva herramienta/conocimiento al perfil de un candidato
# La consulta usa COALESCE para manejar casos donde la lista no existe aún
CY_ADD_TOOL = """
MATCH (c:Candidato {nombre:$cand})
WITH c
SET c.herramientasConocimientos = coalesce(c.herramientasConocimientos, []) + CASE WHEN
$tool IN c.herramientasConocimientos THEN [] ELSE [$tool] END
RETURN c.nombre AS candidato, c.herramientasConocimientos AS herramientas
"""
@tool(
    "tool_corrida_actual",
    description="Tool que permite obtener información sobre la corrida actual. Si existe, devuelve los detalles de la corrida.",
)
def tool_corrida_actual():
    """
    Obtiene información sobre la corrida actual.
    """
    # return run_cypher(CY_ADD_TOOL, {"cand": candidato, "tool": herramienta})[0]
    return print(f"ejecutando la consulta {CY_ADD_TOOL}")