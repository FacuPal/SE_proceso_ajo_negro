
from os import getenv
from typing import Dict, Any
from utils.config import Config

config = Config()

# ============================================================================
# FUNCIÓN HELPER: Ejecutar consultas Cypher en Neo4j
# ============================================================================
def run_cypher(query: str, params: Dict[str, Any] = None):
    """
    Ejecuta una consulta Cypher en Neo4j y retorna los resultados.
    
    Args:
        query: Consulta Cypher (lenguaje de consulta de Neo4j)
        params: Diccionario de parámetros para la consulta
        
    Returns:
        Lista de diccionarios con los datos resultantes
    """
    with config.driver.session() as s:
        res = s.run(query, params or {})
        return [r.data() for r in res]