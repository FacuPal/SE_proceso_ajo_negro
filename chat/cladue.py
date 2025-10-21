import gradio as gr
from langchain_ollama import ChatOllama
from langchain_core.messages import HumanMessage, AIMessage, SystemMessage
import os
from dotenv import load_dotenv
from langgraph.prebuilt import create_react_agent
from langchain_core.prompts import ChatPromptTemplate

from typing import Dict, Any
from tools.corrida_actual import tool_corrida_actual
from utils.agent_config import SYSTEM_PROMPT

# Cargar variables de entorno desde .env si existe
load_dotenv()

# Configuración del modelo Ollama
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "llama3.2:latest")
# Usar host.docker.internal para acceder al host desde el devcontainer
# Si está en el host, usar localhost; si está en container, usar host.docker.internal
OLLAMA_BASE_URL = os.getenv("OLLAMA_HOST", "http://172.17.0.1:11434")
OLLAMA_TEMPERATURE = float(os.getenv("OLLAMA_TEMPERATURE", "0.1"))  # Baja temperatura para ReAct

# Inicializar el modelo de LangChain
llm = ChatOllama(
    model=OLLAMA_MODEL,
    base_url=OLLAMA_BASE_URL,
    temperature=OLLAMA_TEMPERATURE,
)

def get_weather(city: str) -> str:  
    """Get weather for a given city."""
    print("sadfasdfsd")
    return f"It's always sunny in {city}!"

agent = create_react_agent(
    model=llm,
    tools=[get_weather],
)

# Run the agent
agent.invoke(
    {"messages": [{"role": "user", "content": "what is the weather in sf"}]}
)