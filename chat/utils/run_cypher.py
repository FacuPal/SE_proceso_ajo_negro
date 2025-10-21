from neo4j import GraphDatabase
from os import getenv
from typing import Dict, Any

# Configuración de conexión a Neo4j (base de datos de grafos)
NEO4J_URI = getenv("NEO4J_URI", "neo4j://172.17.0.1:7687")
NEO4J_USER = getenv("NEO4J_USER", "neo4j")
NEO4J_PASS = getenv("NEO4J_PASS", "password")

# Crear driver de conexión a Neo4j
driver = GraphDatabase.driver(NEO4J_URI, auth=(NEO4J_USER, NEO4J_PASS))

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
    with driver.session() as s:
        res = s.run(query, params or {})
        return [r.data() for r in res]