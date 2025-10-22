from utils.run_cypher import run_cypher
from langchain_core.tools import tool
from utils.logger import get_logger

logger = get_logger(__name__)

# ============================================================================
# TOOL Corrida Actual: Obtener la corrida actual
# ============================================================================
# Permite obtener de la base de datos la corrida que no tiene fecha de fin asignada.
# Si existe, devuelve los detalles de la corrida.
CY_ADD_TOOL = """
MATCH (c:Corrida)
OPTIONAL MATCH (c)-[rFechaFin:HAS_VALUE {slot: 'fechaFin'}]->(:Slot)
MATCH (c)-[:ETAPA_ACTUAL]->(:Etapa)-[rEtapa:HAS_VALUE {slot: 'name'}]->(:Slot)
WHERE rFechaFin IS NULL
RETURN c.id as id, rEtapa.value as etapa
"""
@tool(
    "tool_corrida_actual",
    description="Tool que permite obtener información sobre la corrida actual. Si existe, devuelve los detalles de la corrida.",
)
def tool_corrida_actual():
    """
    Obtiene información sobre la corrida actual.
    """
    logger.info("Ejecutando tool_corrida_actual")
    return run_cypher(CY_ADD_TOOL)