from typing import Optional
from utils.run_cypher import run_cypher
from langchain_core.tools import tool
from utils.logger import get_logger
from pydantic import BaseModel

logger = get_logger(__name__)

# ============================================================================
# TOOL Registrar Lectura: Permite al usuario cargar una lectura manualmente.
# ============================================================================
CY_ADD_TOOL = """
MATCH (c:Corrida)-[:ETAPA_ACTUAL]->(etapa:Etapa)
OPTIONAL MATCH (c)-[r:HAS_VALUE {slot: 'fechaFin'}]->()
WHERE r IS NULL OR r.value IS NULL
MATCH (LectClass:FrameClass {name:'Lectura'})
MATCH (slLName:Slot {name:'name'})
MATCH (slTs:Slot {name:'ts'})
MATCH (slTempInt:Slot {name:'temperaturaInterna'})
MATCH (slTendencia:Slot {name:'tendencia'})
MATCH (slLCorrida:Slot {name:'corrida'})
MATCH (slLEtapa:Slot {name:'etapa'})
MATCH (slUltimaLectura:Slot {name:'ultimaLectura'})
MATCH (procT:FrameInstance:Etapa {id:'proceso_termico'})
WITH c, LectClass, slLName, slTs, slTempInt, slTendencia, slLCorrida, 
      slLEtapa, slUltimaLectura, procT, datetime() AS now,
      $tempInt AS tempInt, $tendencia AS tendencia

MERGE (l:FrameInstance:Lectura {id:'lectura_' + apoc.create.uuid()})-[:INSTANCE_OF]->(LectClass)
MERGE (l)-[lvName:HAS_VALUE {slot:'name'}]->(slLName)
  ON CREATE SET lvName.value = 'Lectura de ' + c.id, lvName.ts = now
  ON MATCH  SET lvName.value = 'Lectura de ' + c.id, lvName.ts = now

MERGE (l)-[lvTs:HAS_VALUE {slot:'ts'}]->(slTs)
  ON CREATE SET lvTs.value = now, lvTs.ts = now
  ON MATCH  SET lvTs.value = now, lvTs.ts = now

// Valores de ejemplo: temperatura y estado
MERGE (l)-[lvTemp:HAS_VALUE {slot:'temperaturaInterna'}]->(slTempInt)
  ON CREATE SET lvTemp.value = tempInt, lvTemp.ts = now
  ON MATCH  SET lvTemp.value = tempInt, lvTemp.ts = now

MERGE (l)-[lvTend:HAS_VALUE {slot:'tendencia'}]->(slTendencia)
  ON CREATE SET lvTend.value = tendencia, lvTend.ts = now
  ON MATCH  SET lvTend.value = tendencia, lvTend.ts = now

// Referencias: corrida y etapa (valor + relación)
MERGE (l)-[lvCorr:HAS_VALUE {slot:'corrida'}]->(slLCorrida)
  ON CREATE SET lvCorr.value = c.id, lvCorr.ts = now
  ON MATCH  SET lvCorr.value = c.id, lvCorr.ts = now

MERGE (l)-[lvEt:HAS_VALUE {slot:'etapa'}]->(slLEtapa)
  ON CREATE SET lvEt.value = 'proceso_termico', lvEt.ts = now
  ON MATCH  SET lvEt.value = 'proceso_termico', lvEt.ts = now;
"""
@tool(
    "tool_registrar_lectura",
    description="Herramienta para registrar una lectura manualmente a la corrida en curso.",
)
def tool_registrar_lectura(temperatura: Optional[float], tendencia: Optional[float]) -> bool:
    """
    Registra una lectura manualmente en la base de datos Neo4j para la corrida en curso.
    
    Args:
        temperatura: Temperatura interna de la lectura.
        tendencia: Tendencia de la lectura.
    Returns:
        bool: True si la lectura fue cargada exitosamente, False en caso contrario.
    """
    logger.info(f"Ejecutando tool_cargar_lectura con temperatura: {temperatura}, tendencia: {tendencia}")
    try:
        if not temperatura or not tendencia:
            logger.info("Parámetros inválidos para tool_cargar_lectura.")
            return False
        ret = run_cypher(CY_ADD_TOOL, {
            "tempInt": temperatura,
            "tendencia": tendencia
        })
        logger.info(f"Resultado raw de Cypher tool_cargar_lectura: {ret}")
        return True
    except Exception as e:
            logger.info(f"No se pudo registrar la lectura. {str(e)}")
            return False