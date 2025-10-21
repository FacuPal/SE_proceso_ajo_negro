"""
Sistema de Evaluación de Candidatos con Agente LLM + Neo4j

Este script implementa un agente conversacional que puede:
1. Evaluar candidatos contra vacantes usando un grafo de conocimiento en Neo4j
2. Consultar detalles de vacantes y sus criterios
3. Completar información de candidatos
4. Interactuar en lenguaje natural gracias a LangChain y un LLM local

Dependencias:
pip install langchain langchain-community neo4j python-dotenv fastapi uvicorn
"""

# Para LM Studio u Ollama como LLM local, configurar base_url y modelo.
import os
from typing import Dict, Any
from dotenv import load_dotenv
from neo4j import GraphDatabase
from langchain.agents import Tool, AgentExecutor, create_tool_calling_agent
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
from langchain_openai import ChatOpenAI # sirve para LM Studio (API OpenAI-compat) u OpenAI
# Si usás Ollama local: from langchain_community.chat_models import ChatOllama

# ============================================================================
# CONFIGURACIÓN: Carga de variables de entorno
# ============================================================================
load_dotenv()  # Carga variables desde archivo .env

# Configuración de conexión a Neo4j (base de datos de grafos)
NEO4J_URI = os.getenv("NEO4J_URI", "bolt://localhost:7687")
NEO4J_USER = os.getenv("NEO4J_USER", "neo4j")
NEO4J_PASS = os.getenv("NEO4J_PASS", "password")

# Configuración del LLM local (LM Studio por defecto)
# LM Studio expone una API compatible con OpenAI en puerto 1234
LLM_BASE = os.getenv("LLM_BASE", "http://localhost:1234/v1")
LLM_MODEL = os.getenv("LLM_MODEL", "llama-3.1-8b-instruct")
TEMPERATURE = float(os.getenv("LLM_TEMP", "0.3"))  # Temperatura controla creatividad (0=determinístico, 1=creativo)

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
    

# ============================================================================
# TOOL 1: Evaluación Integral de Candidato vs Vacante
# ============================================================================
# Esta consulta Cypher evalúa si un candidato cumple con todos los criterios
# de una vacante específica, verificando:
# - Experiencia específica (Java, Spring Boot, microservicios)
# - Herramientas y conocimientos requeridos
# - Historial laboral relevante
# - Estudios apropiados
CY_EVALUA = """
MATCH (cand:Candidato {nombre:$candidato}), (vac:PuestoConExperiencia {nombre:$vacante})
WITH cand, vac
// a) Experiencia específica
WITH cand, vac
CALL {
WITH cand, vac
WITH cand, vac
RETURN NOT (
cand.experienciaEspecifica CONTAINS 'Java' AND
cand.experienciaEspecifica CONTAINS 'Spring Boot' AND
cand.experienciaEspecifica CONTAINS 'microservicios'
) AS faltaExp
}
CALL {
WITH cand, vac
3
WITH cand, vac
RETURN NOT ALL(req IN ['Java','Spring Boot','Microservicios','NoSQL','Docker'] WHERE req
IN cand.herramientasConocimientos)
AS faltaHerr
}
CALL {
WITH cand, vac
WITH cand, vac
RETURN NOT (cand.historialLaboral CONTAINS 'gran escala' OR cand.historialLaboral CONTAINS
'senior')
AS faltaHist
}
WITH cand, vac, faltaExp, faltaHerr, faltaHist,
(cand.estudios CONTAINS 'Ciencias de la Computación' OR cand.estudios CONTAINS
'Ingeniería') AS okEstudios
WITH {
experiencia: CASE WHEN faltaExp THEN 'NO_CUMPLE' ELSE 'CUMPLE' END,
herramientas: CASE WHEN faltaHerr THEN 'NO_CUMPLE' ELSE 'CUMPLE' END,
historial: CASE WHEN faltaHist THEN 'NO_CUMPLE' ELSE 'CUMPLE' END,
estudios: CASE WHEN okEstudios THEN 'CUMPLE' ELSE 'NO_CUMPLE' END
} AS criterios, cand, vac
WITH criterios, cand, vac,
(criterios.experiencia='NO_CUMPLE' OR criterios.herramientas='NO_CUMPLE' OR
criterios.historial='NO_CUMPLE') AS algunFail
RETURN {
candidato: cand.nombre,
vacante: vac.nombre,
criterios: criterios,
decision: CASE WHEN algunFail THEN 'NO_APTO' ELSE 'APTO' END
} AS resultado
"""
def tool_evalua_cv(candidato: str, vacante: str):
    """
    Evalúa si un candidato es APTO o NO_APTO para una vacante.
    
    Args:
        candidato: Nombre del candidato a evaluar
        vacante: Nombre de la vacante/puesto
        
    Returns:
        Diccionario con el resultado de la evaluación incluyendo:
        - candidato: nombre
        - vacante: nombre
        - criterios: dict con estado de cada criterio (CUMPLE/NO_CUMPLE)
        - decision: APTO o NO_APTO
    """
    rows = run_cypher(CY_EVALUA, {"candidato": candidato, "vacante": vacante})
    return rows[0]["resultado"] if rows else {"error": "Sin datos"}


# ============================================================================
# TOOL 2: Detalle de Vacante - Consulta de Requisitos
# ============================================================================
# Esta consulta obtiene todos los criterios que requiere una vacante específica
CY_DETALLE_VAC = """
MATCH (v:PuestoConExperiencia {nombre:$vac})-[:REQUIERE]->(c:Criterio)
RETURN v.nombre AS vacante, collect(c.nombre) AS criterios
"""

def tool_detalle_vacante(vacante: str):
    """
    Obtiene la lista de criterios que requiere una vacante.
    
    Args:
        vacante: Nombre de la vacante/puesto
        
    Returns:
        Diccionario con:
        - vacante: nombre de la vacante
        - criterios: lista de nombres de criterios requeridos
    """
    rows = run_cypher(CY_DETALLE_VAC, {"vac": vacante})
    return rows[0] if rows else {"vacante": vacante, "criterios": []}



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

def tool_completar_dato_herr(candidato: str, herramienta: str):
    """
    Agrega una herramienta/conocimiento al perfil de un candidato.
    Evita duplicados verificando si ya existe en la lista.
    
    Args:
        candidato: Nombre del candidato
        herramienta: Nombre de la herramienta a agregar
        
    Returns:
        Diccionario con el candidato y su lista actualizada de herramientas
    """
    return run_cypher(CY_ADD_TOOL, {"cand": candidato, "tool": herramienta})[0]
# ============================================================================
# CONFIGURACIÓN DEL LLM Y TOOLS PARA EL AGENTE
# ============================================================================
# LLM local: LM Studio (OpenAI-compatible). Para Ollama, usar ChatOllama.
# ChatOpenAI funciona con cualquier API compatible con OpenAI (LM Studio, vLLM, etc.)
llm = ChatOpenAI(
    base_url=LLM_BASE, 
    api_key="not-needed",  # LM Studio no requiere API key real
    model=LLM_MODEL,
    temperature=TEMPERATURE
)

# Definición de las herramientas (tools) que el agente puede usar
# Cada tool es una función que el LLM puede decidir llamar según la consulta del usuario
tools = [
    Tool.from_function(
        name="evalua_cv",
        description="Evalúa un candidato contra una vacante. Args: candidato (str), vacante (str).",
        func=lambda candidato, vacante: tool_evalua_cv(candidato, vacante),
    ),
    Tool.from_function(
        name="detalle_vacante",
        description="Lista los criterios requeridos para una vacante. Arg: vacante (str).",
        func=lambda vacante: tool_detalle_vacante(vacante),
    ),
    Tool.from_function(
        name="completar_herramienta",
        description="Agrega una herramienta al candidato. Args: candid  ato (str), herramienta (str).",
        func=lambda candidato, herramienta: tool_completar_dato_herr(candidato, herramienta),
    ),
]
# ============================================================================
# PROMPT DEL SISTEMA Y CONFIGURACIÓN DEL AGENTE
# ============================================================================
# El prompt del sistema define el comportamiento y personalidad del agente
SYSTEM_PROMPT = """
Eres un asistente de selección que usa un grafo de frames en Neo4j.
Política: no inventar. Si falta info, pedirla. Usa primero la tool evalua_cv para dictámenes.
Formato de respuesta:
1) Resumen,
2) Detalle por criterio,
3) Evidencia (tools y parámetros),
4) Próximos pasos.
"""

# Template de prompt que incluye:
# - system: instrucciones del sistema
# - chat_history: historial de conversación para contexto
# - human: entrada actual del usuario
prompt = ChatPromptTemplate.from_messages([
    ("system", SYSTEM_PROMPT),
    MessagesPlaceholder("chat_history"),
    ("human", "{input}")
])

# Crear el agente que puede llamar a las tools definidas
agent = create_tool_calling_agent(llm, tools, prompt)

# Executor: envoltorio que maneja la ejecución del agente y sus tools
# verbose=False: no muestra los pasos internos del agente
executor = AgentExecutor(agent=agent, tools=tools, verbose=False)


# ============================================================================
# EJEMPLOS DE USO
# ============================================================================
# El agente puede responder a consultas en lenguaje natural:
#
# Ejemplo 1: Evaluar un candidato
# executor.invoke({"input": "¿JuanCV es apto para VacanteJava?"})
#
# Ejemplo 2: Completar datos y reevaluar
# executor.invoke({"input": "Agregá Docker a JuanCV y reevaluá contra VacanteJava."})
#
# Ejemplo 3: Consultar requisitos
# executor.invoke({"input": "¿Qué criterios requiere la VacanteJava?"})
#
# El agente decidirá automáticamente qué tools usar según la pregunta

if __name__ == "__main__":
    # Ejemplo interactivo simple
    print("=== Sistema de Evaluación de Candidatos ===")
    print("El agente está listo. Usa executor.invoke({'input': 'tu pregunta'}) para interactuar.")
    print("\nEjemplo:")
    print("  executor.invoke({'input': '¿JuanCV es apto para VacanteJava?'})")
    print("\nNota: Asegúrate de tener Neo4j corriendo y datos cargados.")
