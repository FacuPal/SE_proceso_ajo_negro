import gradio as gr
from langchain_core.messages import HumanMessage, SystemMessage
from prompts.system_prompt import SYSTEM_PROMPT
from agents.ollama_agent import get_agent
from utils.logger import get_logger

# Configurar logger para este módulo
logger = get_logger(__name__)

class ChatApp():
    def __init__(self):
        # Obtener el agente
        self.agent = get_agent()

    def chat(self, message, history):
        """
        Función que procesa el mensaje del usuario y obtiene respuesta de Llama3.2 via LangChain.
        
        Args:
            message: El mensaje actual del usuario
            history: Historial de la conversación (lista de mensajes)   
        
        Returns:
            La respuesta generada por el modelo
        """
        try:
            logger.info(f"Mensaje recibido: {message}")
            # Armar mensajes con el prompt del sistema
            messages = [
                SystemMessage(content=SYSTEM_PROMPT),
                HumanMessage(content=message)
            ]
    
            # Invocar el modelo con LangChain
            response = self.agent.invoke({
                "messages": messages
            })
            logger.info(f"Respuesta del modelo: {response['messages'][-1].content}")

            return response["messages"][-1].content

        except Exception as e:
            return f"❌ Error al invocar el modelo: {str(e)}"



if __name__ == "__main__":
    # Crear instancia de la aplicación de chat
    app = ChatApp()
    
    # Interfaz de Gradio con ChatInterface
    gr.ChatInterface(
        fn=app.chat,
        type="messages",
        title="🧄 Asistente mAIllard 🧄",
        description="Asistente inteligente para el proceso de fermentación de ajo negro.",
        examples=[
            "¿Qué es el ajo negro?",
            "¿Cuál es la temperatura ideal para la fermentación?",
            "¿Existe algúna corrida activa?",
            "¿Cual es la temperatura actual?",
            "¿Qué acción recomienda el sistema?",
            "¿Hay alguna alerta activa?",
            "¿Puedo registrar una lectura manualmente?"
        ],
    ).launch()
    