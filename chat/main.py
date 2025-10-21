import gradio as gr
from langchain_ollama import ChatOllama
from langchain_core.messages import HumanMessage, AIMessage, SystemMessage
import os
from dotenv import load_dotenv
# from langchain.agents import AgentExecutor, create_tool_calling_agent
# from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder

from typing import Dict, Any
from langchain.agents import create_agent
from tools.corrida_actual import tool_corrida_actual
from utils.agent_config import SYSTEM_PROMPT

# Cargar variables de entorno desde .env si existe
load_dotenv()

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

agent = create_agent(
    llm,
    tools=[
        tool_corrida_actual
    ],
)


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
        # llm_with_tools = agent.bind_tools(tools)
        response = agent.invoke({
            "messages": messages
        })

        return response["messages"][-1].content

    except Exception as e:
        return f"❌ Error al invocar el modelo: {str(e)}"


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