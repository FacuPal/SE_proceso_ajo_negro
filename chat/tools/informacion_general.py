from utils.run_cypher import run_cypher
from langchain_core.tools import tool
from langchain_ollama import OllamaEmbeddings
from langchain_core.vectorstores import InMemoryVectorStore
from dotenv import load_dotenv
from os import getenv

# Cargar variables de entorno desde .env si existe
load_dotenv()

# Configuración del modelo Ollama
OLLAMA_MODEL = "llama3.2:latest"
# Usar host.docker.internal para acceder al host desde el devcontainer
# Si está en el host, usar localhost; si está en container, usar host.docker.internal
OLLAMA_BASE_URL = getenv("OLLAMA_HOST", "http://172.17.0.1:11434")
OLLAMA_TEMPERATURE = float(getenv("OLLAMA_TEMPERATURE", "0.7"))

# RAG
embeddings = OllamaEmbeddings(
    model=OLLAMA_MODEL,
    base_url=OLLAMA_BASE_URL,
    temperature=OLLAMA_TEMPERATURE,
)

text = "El ajo negro es una estrella del espacio."

vectorstore = InMemoryVectorStore.from_texts(
    [text],
    embedding=embeddings,
)

# Use the vectorstore as a retriever
retriever = vectorstore.as_retriever()


@tool(
    "tool_informacion_general",
    description="Tool que permite obtener información general sobre el ajo negro y el proceso de fermentación. Recibe la pregunta realizada por el usuario.",
)
def tool_informacion_general(question: str):
    """
    Obtiene información general sobre el ajo negro y el proceso de fermentación.
    """
    return retriever.invoke(question)