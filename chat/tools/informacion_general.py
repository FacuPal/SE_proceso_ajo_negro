from langchain_core.tools import tool
from utils.config import Config
from agents.ollama_retriever import get_retriever
from utils.logger import get_logger

logger = get_logger(__name__)

# Obtener retriever para consultas RAG
retriever = get_retriever()


@tool(
    "tool_informacion_general",
    description="Tool que permite obtener información general sobre el ajo negro y el proceso de fermentación. Recibe la pregunta realizada por el usuario.",
)
def tool_informacion_general(question: str):
    """
    Obtiene información general sobre el ajo negro y el proceso de fermentación.
    """
    logger.info(f"Consultando información general con la pregunta: {question}")
    return retriever.invoke(question)