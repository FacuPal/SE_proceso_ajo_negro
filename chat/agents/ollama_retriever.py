from langchain_ollama import OllamaEmbeddings
from langchain_core.vectorstores import InMemoryVectorStore
from langchain_community.document_loaders import PyPDFLoader
from langchain_text_splitters import RecursiveCharacterTextSplitter
from utils.config import Config
from pathlib import Path
# Cargar configuración
config = Config()

# Ruta a los documentos
DOCS_PATH = Path(__file__).parent.parent / "documents"

def get_retriever():
    """
    Crea y retorna un retriever basado en OllamaEmbeddings y documentos cargados.
    """

    # RAG
    embeddings = OllamaEmbeddings(
        model=config.RAG_MODEL,
        base_url=config.OLLAMA_BASE_URL, 
        temperature=config.OLLAMA_TEMPERATURE,
    )

    # Cargar documentos 
    def load_documents():
        loader = PyPDFLoader(DOCS_PATH / "ajo_negro.pdf")
        documents = loader.load()


        text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=1000, chunk_overlap=200, add_start_index=True
        )
        return text_splitter.split_documents(documents)


    # Split de documentos 
    all_splits = load_documents()

    # Se crea el vectorstore
    vectorstore = InMemoryVectorStore(embeddings)

    # Indexamos los docs
    vectorstore.add_documents(all_splits)

    # Retornamos el retriever
    return vectorstore.as_retriever()