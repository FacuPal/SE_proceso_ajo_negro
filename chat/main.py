import gradio as gr
from langchain_community.chat_models import ChatOllama
from langchain_core.messages import HumanMessage, AIMessage, SystemMessage
import os
from dotenv import load_dotenv
# from langchain.agents import AgentExecutor, create_tool_calling_agent
# from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
from langchain_core.tools import tool
from neo4j import GraphDatabase
from typing import Dict, Any



# Cargar variables de entorno desde .env si existe
load_dotenv()

# Configuración de conexión a Neo4j (base de datos de grafos)
NEO4J_URI = os.getenv("NEO4J_URI", "neo4j://172.17.0.1:7687")
NEO4J_USER = os.getenv("NEO4J_USER", "neo4j")
NEO4J_PASS = os.getenv("NEO4J_PASS", "password")

# Configuración del modelo Ollama
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "llama3.2:latest")
# Usar host.docker.internal para acceder al host desde el devcontainer
# Si está en el host, usar localhost; si está en container, usar host.docker.internal
OLLAMA_BASE_URL = os.getenv("OLLAMA_HOST", "http://172.17.0.1:11434")
OLLAMA_TEMPERATURE = float(os.getenv("OLLAMA_TEMPERATURE", "0.7"))

# Inicializar el modelo de LangChain
llm = ChatOllama(
    model=OLLAMA_MODEL,
    base_url=OLLAMA_BASE_URL,
    temperature=OLLAMA_TEMPERATURE,
)

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
@tool(
    description="Evalúa un candidato contra una vacante. Args: candidato (str), vacante (str).",
)
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
@tool(
    description="Lista los criterios requeridos para una vacante. Arg: vacante (str).",
)
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
@tool(
    description="Agrega una herramienta al candidato. Args: candidato (str), herramienta (str).",
)
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

# Definición de las herramientas (tools) que el agente puede usar
# Cada tool es una función que el LLM puede decidir llamar según la consulta del usuario
tools = [
    tool_evalua_cv,
    tool_detalle_vacante,
    tool_completar_dato_herr,
]



# Prompt del sistema para definir el comportamiento del asistente
SYSTEM_PROMPT = """
Eres mAIllard, un asistente experto en el proceso de fermentación de ajo negro que usa una red de marcos en Neo4j.

Política: No inventar información. Si falta información, pedirla.

Tu objetivo es brindar información al operador del proceso acerca de:
- La corrida en curso: Consultas sobre si existe una corrida (tanda/proceso) activa, y su etapa actual.
- Estado de los parámetros: Estado actual en tiempo real de variables (temperatura, humedad) y actuadores (calefactor/ventilador).
- Información histórica de los parámetros: Solicitudes de historial/tendencias/series temporales y comparativas de las variables (temperatura, humedad) de una corrida en particular.
- Recomendaciones: Información acerca de las acciones/recomendaciones sugeridas por el sistema experto.
- Alertas: Pedidos de alertas/incidentes (incendio, puerta abierta, críticas) actuales o históricas.

Responde de forma clara, precisa y amigable en español.
Formato de respuesta:
1) Resumen,
2) Detalle por criterio,
3) Evidencia (tools y parámetros),
"""


def chat_with_llama(message, history):
    """
    Función que procesa el mensaje del usuario y obtiene respuesta de Llama3.2 via LangChain.
    
    Args:
        message: El mensaje actual del usuario
        history: Historial de la conversación (lista de mensajes)
    
    Returns:
        La respuesta generada por el modelo
    """
    try:
        # Construir el historial de mensajes para LangChain
        messages = [SystemMessage(content=SYSTEM_PROMPT)]
        
        # Agregar historial previo si existe
        for msg in history:
            if isinstance(msg, dict):
                # Formato nuevo de Gradio con roles
                if msg.get("role") == "user":
                    messages.append(HumanMessage(content=msg.get("content", "")))
                elif msg.get("role") == "assistant":
                    messages.append(AIMessage(content=msg.get("content", "")))
            elif isinstance(msg, (list, tuple)) and len(msg) == 2:
                # Formato antiguo de Gradio: (user_msg, bot_msg)
                messages.append(HumanMessage(content=msg[0]))
                if msg[1]:
                    messages.append(AIMessage(content=msg[1]))
        
        # Agregar mensaje actual del usuario
        messages.append(HumanMessage(content=message))
        
        # Invocar el modelo con LangChain
        # response = llm.invoke(messages)
        llm_with_tools = llm.bind_tools(tools)
        response = llm_with_tools.invoke(messages)

        # # Template de prompt que incluye:
        # # - system: instrucciones del sistema
        # # - chat_history: historial de conversación para contexto
        # # - human: entrada actual del usuario
        # prompt = ChatPromptTemplate.from_messages([
        #     ("system", SYSTEM_PROMPT),
        #     MessagesPlaceholder("chat_history"),
        #     ("human", "{input}")
        # ])

        # # Crear el agente que puede llamar a las tools definidas
        # agent = create_tool_calling_agent(llm, tools, prompt)

        # # Executor: envoltorio que maneja la ejecución del agente y sus tools
        # # verbose=False: no muestra los pasos internos del agente
        # executor = AgentExecutor(agent=agent, tools=tools, verbose=False)

        
        return response.content
    
    except Exception as e:
        return f"❌ Error al conectar con Ollama: {str(e)}\n\nAsegúrate de que:\n1. Ollama está corriendo en el HOST: ollama serve\n2. El modelo está descargado: ollama pull llama3.2:latest\n3. Desde el devcontainer, Ollama debe estar en: {OLLAMA_BASE_URL}"


# Interfaz de Gradio con ChatInterface

# Interfaz de Gradio con ChatInterface
gr.ChatInterface(
    fn=chat_with_llama, 
    type="messages",
    title="🦆 Asistente mAIllard",
    description="Asistente para el proceso de fermentación de ajo negro potenciado por IA (Llama3.2) y Neo4j.",
    examples=[
        "¿Qué es el ajo negro?",
        "¿Cuál es la temperatura ideal para la fermentación?",
        "Explícame el proceso de fermentación del ajo negro",
    ],
).launch()