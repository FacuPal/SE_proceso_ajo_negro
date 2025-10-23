from typing import Optional
from utils.run_cypher import run_cypher
from langchain_core.tools import tool
from utils.logger import get_logger
from pydantic import BaseModel

logger = get_logger(__name__)

class Alerta(BaseModel):
    ts: str
    tipo: str
    activa: bool
    explicacion: str

# ============================================================================
# TOOL Alertas: Obtiene las alertas disparadas por el sistema experto
# ============================================================================
# Permite obtener de la base de datos las alertas activas de la corrida en ejecución.
CY_ADD_TOOL = """
MATCH (c:Corrida {id: $idCorrida})-[rAlerta:ALERTA]->(a:Alerta)
MATCH (a)-[rTs:HAS_VALUE {slot: 'ts'}]->(:Slot)
MATCH (a)-[rName:HAS_VALUE {slot: 'name'}]->(:Slot)
MATCH (a)-[rActivo:HAS_VALUE {slot: 'activo'}]->(:Slot)
MATCH (a)-[rExplicacion:HAS_VALUE {slot: 'explicacion'}]->(:Slot)
WHERE rActivo IS NOT NULL and rActivo.value = true
RETURN  toString(rTs.value) as ts,
        rName.value as tipo,
        rActivo.value as activa,
        rExplicacion.value as explicacion
"""
@tool(
    "tool_alertas",
    description="Herramienta para obtener las alertas disparadas por el sistema experto.",
)
def tool_alertas(id_corrida: str) -> Optional[list[Alerta]]:
    """
    Obtiene las alertas disparadas por el sistema experto en base a los parámetros de temperatura y estado de actuadores. 
    Requiere obtener el id de la corrida actual mediante la herramienta tool_corrida_actual.

    Args:
        id_corrida: ID de la corrida actual. Proviene del resultado de tool_corrida_actual.
    Returns:
        list[Alerta] o None si no hay corrida activa o no hay alertas activas.
    """
    logger.info(f"Ejecutando tool_alertas con id_corrida: {id_corrida}")
    try:
        ret = run_cypher(CY_ADD_TOOL, {
            "idCorrida": id_corrida
        })
        logger.info(f"Resultado raw de Cypher tool_alertas: {ret}")
        response = [Alerta.model_validate(item) for item in ret]
        logger.info(f"Resultado tool_alertas: {response}")
        return response
    except Exception as e:
            logger.info(f"No hay corrida activa o no hay alertas activas. {str(e)}")
            return None