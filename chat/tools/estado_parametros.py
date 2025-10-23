from typing import Optional
from utils.run_cypher import run_cypher
from langchain_core.tools import tool
from utils.logger import get_logger
from pydantic import BaseModel

logger = get_logger(__name__)

class EstadoActual(BaseModel):
    ts: str
    temperatura_esperada: float
    temperatura_actual: float
    tendencia: float
    u_baja: float
    u_en_rango: float
    u_alta: float
    u_calefactor_prendido: float
    u_calefactor_apagado: float
    u_ventilador_prendido: float
    u_ventilador_apagado: float

# ============================================================================
# TOOL Estado Parametros: Obtiene el estado de los parámetros de la corrida actual
# ============================================================================
# Permite obtener de la base de datos los parámetros de la corrida en ejecución.
CY_ADD_TOOL = """
MATCH (c:Corrida {id: $idCorrida})-[:ULTIMA_LECTURA]->(l:Lectura)
MATCH (l)-[:EN_ETAPA]->(e:Etapa)
MATCH (e)-[:CONFIGURACION_TEMPERATURA]->(rg:Rango)
MATCH (rg)-[rTempEsperada:HAS_VALUE {slot: 'valorEsperado'}]->(:Slot)
MATCH (l)-[rTs:HAS_VALUE {slot: 'ts'}]->(:Slot)
MATCH (l)-[rTemperatura:HAS_VALUE {slot: 'temperaturaInterna'}]->(:Slot)
MATCH (l)-[rTendencia:HAS_VALUE {slot: 'tendencia'}]->(:Slot)
MATCH (l)-[rUBaja:HAS_VALUE {slot: 'uBaja'}]->(:Slot)
MATCH (l)-[rUEnRango:HAS_VALUE {slot: 'uEnRango'}]->(:Slot)
MATCH (l)-[rUAlta:HAS_VALUE {slot: 'uAlta'}]->(:Slot)
MATCH (cal:Actuador {id: 'calefactor'})
MATCH (cal)-[rCalUPrendido:HAS_VALUE {slot: 'uPrendido'}]->(:Slot)
MATCH (cal)-[rCalUApagado:HAS_VALUE {slot: 'uApagado'}]->(:Slot)
MATCH (vent:Actuador {id: 'ventilador'})
MATCH (vent)-[rVentUPrendido:HAS_VALUE {slot: 'uPrendido'}]->(:Slot)
MATCH (vent)-[rVentUApagado:HAS_VALUE {slot: 'uApagado'}]->(:Slot)
RETURN  toString(rTs.value) as ts, 
        rTempEsperada.value as temperatura_esperada, 
        rTemperatura.value as temperatura_actual, 
        rTendencia.value as tendencia, 
        rUBaja.value as u_baja, 
        rUEnRango.value as u_en_rango, 
        rUAlta.value as u_alta, 
        rCalUPrendido.value as u_calefactor_prendido,
        rCalUApagado.value as u_calefactor_apagado,
        rVentUPrendido.value as u_ventilador_prendido,
        rVentUApagado.value as u_ventilador_apagado
"""
@tool(
    "tool_estado_parametros",
    description="Herramienta para obtener información sobre el estado de los parámetros de la corrida actual. Si devuelve null, se considera que no hay corrida activa.",
)
def tool_estado_parametros(id_corrida: str) -> Optional[EstadoActual]:
    """
    Obtiene el estado actual de los parámetros de la corrida actual, proveniente de la tool_corrida_actual, entre los cuales se encuentran:
        - ts: timestamp de la última lectura
        - temperatura_esperada: temperatura objetivo para la etapa actual
        - temperatura_actual: temperatura actual de la etapa
        - tendencia: tendencia de la temperatura en °C/min.
        - u_baja: Valor fuzzificado de pertenencia a baja temperatura
        - u_en_rango: Valor fuzzificado de pertenencia a temperatura en rango
        - u_alta: Valor fuzzificado de pertenencia a alta temperatura
        - u_calefactor_prendido: Valor fuzzificado de pertenencia a calefactor prendido
        - u_calefactor_apagado: Valor fuzzificado de pertenencia a calefactor apagado
        - u_ventilador_prendido: Valor fuzzificado de pertenencia a ventilador prendido
        - u_ventilador_apagado: Valor fuzzificado de pertenencia a ventilador apagado
    
    Args:
        id_corrida: ID de la corrida actual. Proviene del resultado de tool_corrida_actual.
    Returns:
        EstadoActual o None si no hay corrida activa o no hay información de la última lectura.
    """
    logger.info(f"Ejecutando tool_estado_parametros con id_corrida: {id_corrida}")
    try:
        ret = run_cypher(CY_ADD_TOOL, {
            "idCorrida": id_corrida
        })[0]
        logger.info(f"Resultado raw de Cypher tool_estado_parametros: {ret}") 
        response = EstadoActual.model_validate(ret)
        logger.info(f"Resultado tool_estado_parametros: {response}")
        return response
    except Exception as e:
            logger.info(f"No hay corrida activa o no hay lecturas disponibles. {str(e)}")
            return None