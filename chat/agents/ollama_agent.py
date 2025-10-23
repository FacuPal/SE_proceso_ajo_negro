from langchain_ollama import ChatOllama
from langchain.agents import create_agent
from tools.corrida_actual import tool_corrida_actual
from tools.informacion_general import tool_informacion_general
from utils.config import Config

# Configuración 
config = Config()

def get_agent():
    """
    Función que inicializa y retorna el agente de LangChain con las herramientas y configuración dadas.
    
    Returns:
        agent: El agente creado con LangChain
    """

    # Inicializar el modelo de LangChain
    llm = ChatOllama(
        model=config.OLLAMA_MODEL,
        base_url=config.OLLAMA_BASE_URL,
        temperature=config.OLLAMA_TEMPERATURE,
        reasoning=config.OLLAMA_REASONING,
        top_k=config.OLLAMA_TOP_K,
        top_p=config.OLLAMA_TOP_P,
    )

    return create_agent(
        llm,
        tools=[
            tool_corrida_actual,
            tool_informacion_general,
        ],
    )
