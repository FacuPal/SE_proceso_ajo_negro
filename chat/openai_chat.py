import gradio as gr
from langchain_core.messages import HumanMessage, AIMessage, SystemMessage
import os
from dotenv import load_dotenv
from langchain_core.tools import tool
from neo4j import GraphDatabase
from typing import Dict, Any
from langchain_openai import ChatOpenAI


# Cargar variables de entorno desde .env si existe
load_dotenv()

# Configuración de conexión a Neo4j (base de datos de grafos)
NEO4J_URI = os.getenv("NEO4J_URI", "neo4j://172.17.0.1:7687")
NEO4J_USER = os.getenv("NEO4J_USER", "neo4j")
NEO4J_PASS = os.getenv("NEO4J_PASS", "password")

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")

llm = ChatOpenAI(
    model="mistral",  # Mucho más barato que gpt-4o (60x menos costoso)
    temperature=0,
    max_tokens=20,        
    timeout=None,
    max_retries=2,
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
    tool_completar_dato_herr
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
        
        return response.content
    
    except Exception as e:
        return f"❌ Error al conectar con Ollama: {str(e)}\n\nAsegúrate de que:\n1. Ollama está corriendo en el HOST: ollama serve\n2. El modelo está descargado: ollama pull llama3.2:latest\n3. Desde el devcontainer, Ollama debe estar en: {OLLAMA_BASE_URL}"


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