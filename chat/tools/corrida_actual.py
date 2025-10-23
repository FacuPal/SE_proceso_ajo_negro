from typing import Optional
from utils.run_cypher import run_cypher
from langchain_core.tools import tool
from utils.logger import get_logger
from pydantic import BaseModel

logger = get_logger(__name__)

class Corrida(BaseModel):
    id: str
    etapa: str

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
    description="Herramienta para obtener información sobre la corrida actual. Si devuelve null, se considera que no hay corrida activa.",

)
def tool_corrida_actual()->Optional[Corrida]:
    """
    Obtiene información sobre la corrida actual.
    Returns:
        Corrida actual o None si no hay corrida activa.
    """
    logger.info("Ejecutando tool_corrida_actual")
    try:
        response = Corrida.model_validate(run_cypher(CY_ADD_TOOL)[0])
        logger.info(f"Resultado tool_corrida_actual: {response}")
        return response
    except Exception as e:
            logger.info("No hay corrida activa.")
            return None