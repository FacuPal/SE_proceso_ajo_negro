from typing import Optional
from utils.run_cypher import run_cypher
from langchain_core.tools import tool
from utils.logger import get_logger
from pydantic import BaseModel

logger = get_logger(__name__)

class Recomendacion(BaseModel):
    ts_recomendacion: str
    accion: str

# ============================================================================
# TOOL Recomendaciones: Obtiene el las recomendaciones realizadas por el sistema experto
# ============================================================================
# Permite obtener de la base de datos los parámetros de la corrida en ejecución.
CY_ADD_TOOL = """
MATCH (c:Corrida {id: $idCorrida})-[rRecomienda:RECOMIENDA]->(r:Recomendacion)
MATCH (r)-[rName:HAS_VALUE {slot: 'name'}]->(:Slot)
RETURN  toString(rRecomienda.ts) as ts_recomendacion,
        rName.value as accion
"""
@tool(
    "tool_recomendaciones",
    description="Herramienta para obtener las recomendaciones realizadas por el sistema experto.",
)
def tool_recomendaciones(id_corrida: str) -> Optional[list[Recomendacion]]:
    """
    Obtiene las recomendaciones realizadas por el sistema experto en base a los parámetros de temperatura y estado de actuadores.
    
    Args:
        id_corrida: ID de la corrida actual. Proviene del resultado de tool_corrida_actual.
    Returns:
        list[Recomendacion] o None si no hay corrida activa o no hay recomendaciones.
    """
    logger.info(f"Ejecutando tool_recomendaciones con id_corrida: {id_corrida}")
    try:
        ret = run_cypher(CY_ADD_TOOL, {
            "idCorrida": id_corrida
        })
        logger.info(f"Resultado raw de Cypher tool_recomendaciones: {ret}")
        response = [Recomendacion.model_validate(item) for item in ret]
        logger.info(f"Resultado tool_recomendaciones: {response}")
        return response
    except Exception as e:
            logger.info(f"No hay corrida activa o no hay recomendaciones disponibles. {str(e)}")
            return None