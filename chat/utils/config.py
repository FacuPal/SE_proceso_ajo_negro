from dotenv import load_dotenv
from os import getenv
from neo4j import GraphDatabase

# Cargar variables de entorno desde .env si existe
load_dotenv()

class Config:
    """
    Clase de configuración para la aplicación (Singleton).
    Carga variables de entorno necesarias.
    """
    _instance = None
    _initialized = False

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(Config, cls).__new__(cls)
        return cls._instance

    def __init__(self):
        if not Config._initialized:
            # Configuración de conexión a Neo4j (base de datos de grafos)
            self.NEO4J_URI = getenv("NEO4J_URI", "neo4j://172.17.0.1:7687")
            self.NEO4J_USER = getenv("NEO4J_USER", "neo4j")
            self.NEO4J_PASS = getenv("NEO4J_PASS", "password")

            # Configuración del modelo Ollama
            self.OLLAMA_MODEL = getenv("OLLAMA_MODEL", "llama3.2:latest")
            self.OLLAMA_BASE_URL = getenv("OLLAMA_HOST", "http://172.17.0.1:11434")
            # Según buenas prácticas https://huggingface.co/Qwen/Qwen3-4B#best-practices
            self.OLLAMA_REASONING = False
            try:
                self.OLLAMA_TEMPERATURE = float(getenv("OLLAMA_TEMPERATURE", "0.7"))
            except (TypeError, ValueError):
                self.OLLAMA_TEMPERATURE = 0.7
            self.OLLAMA_TOP_K = 20
            self.OLLAMA_TOP_P = 0.8

            # Configuración del modelo de embedding
            self.RAG_MODEL = getenv("RAG_MODEL", "embeddinggemma:latest")

            # Crear driver de conexión a Neo4j
            self.driver = GraphDatabase.driver(self.NEO4J_URI, auth=(self.NEO4J_USER, self.NEO4J_PASS))
            
            Config._initialized = True