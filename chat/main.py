import gradio as gr
from langchain_core.messages import HumanMessage, AIMessage, SystemMessage
from agents.system_prompt import SYSTEM_PROMPT
from agents.ollama_agent import retrieve_agent
from utils.logger import get_logger

# Configurar logger para este módulo
logger = get_logger(__name__)

# Obtener el agente
agent = retrieve_agent()

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
        # Armar mensajes con el prompt del sistema
        messages = [
            SystemMessage(content=SYSTEM_PROMPT),
            HumanMessage(content=message)
        ]
  
        # Invocar el modelo con LangChain
        response = agent.invoke({
            "messages": messages
        })

        return response["messages"][-1].content

    except Exception as e:
        return f"❌ Error al invocar el modelo: {str(e)}"



if __name__ == "__main__":
    # Interfaz de Gradio con ChatInterface
    gr.ChatInterface(
        fn=chat_with_llama, 
        type="messages",
        title="🧄 Asistente mAIllard 🧄",
        description="Asistente inteligente para el proceso de fermentación de ajo negro.",
        examples=[
            "¿Qué es el ajo negro?",
            "¿Cuál es la temperatura ideal para la fermentación?",
            "Explícame el proceso de fermentación del ajo negro",
            "¿Existe algúna corrida activa?"
        ],
    ).launch()
    