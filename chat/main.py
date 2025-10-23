import json
import gradio as gr
from langchain_core.messages import HumanMessage, SystemMessage
from prompts.system_prompt import SYSTEM_PROMPT
from prompts.classification_prompt import CLASSIFICATION_PROMPT
from agents.ollama_agent import retrieve_agent
from utils.logger import get_logger
from tools.corrida_actual import tool_corrida_actual

# Configurar logger para este módulo
logger = get_logger(__name__)


class ChatApp:
    """
    Aplicación de chat que clasifica consultas y ejecuta lógica específica por categoría.
    """
    
    

    def __init__(self):
        """Inicializa el agente y recursos necesarios."""
        self.agent = retrieve_agent()
        logger.info("ChatApp inicializada con agente Ollama.")
    
    def classify_query(self, message: str) -> str:
        """
        Clasifica la consulta del usuario en una categoría.
        
        Args:
            message: Consulta del usuario
            
        Returns:
            Categoría detectada: 'corrida_actual', 'estado_variables' o 'otra_consulta'
        """
        content = ""
        try:
            prompt = CLASSIFICATION_PROMPT.format(question=message)
            messages = [HumanMessage(content=prompt)]
            
            result = self.agent.invoke({"messages": messages})  # type: ignore
            content = result["messages"][-1].content
            
            logger.info(f"Respuesta de clasificación: {content}")
            
            # Parsear JSON de la respuesta
            # Buscar primer '{' y último '}' para extraer JSON válido
            start = content.find("{")
            end = content.rfind("}") + 1
            if start >= 0 and end > start:
                json_str = content[start:end]
                data = json.loads(json_str)
                category = data.get("category", "otra_consulta")
                logger.info(f"Categoría detectada: {category}")
                return category
            else:
                logger.warning("No se encontró JSON en la respuesta, usando 'otra_consulta'")
                return "otra_consulta"
                
        except json.JSONDecodeError as e:
            logger.error(f"Error al parsear JSON de clasificación: {e}. Contenido: {content}")
            return "otra_consulta"
        except Exception as e:
            logger.error(f"Error en clasificación: {e}")
            return "otra_consulta"
    
    def handle_corrida_actual(self) -> str:
        """
        Maneja consultas sobre corrida actual.
        
        Returns:
            Información de la corrida actual
        """
        logger.info("Ejecutando lógica para corrida_actual")
        try:
            # Invocar la tool usando .invoke() para BaseTool de LangChain
            result = tool_corrida_actual.invoke({})
            prompt = SYSTEM_PROMPT.format(question="Resultado obtenido de la herramienta de corrida actual: " + str(result))
            return self._query_agent(prompt)
        except Exception as e:
            logger.error(f"Error al obtener corrida actual: {e}")
            return f"❌ Error al consultar la corrida actual: {str(e)}"
    
    def handle_estado_variables(self, message: str) -> str:
        """
        Maneja consultas sobre el estado de variables del sistema.
        
        Args:
            message: Consulta original del usuario
            
        Returns:
            Estado de las variables solicitadas
        """
        logger.info("Ejecutando lógica para estado_variables")
        # TODO: Implementar consulta de variables en tiempo real
        # Por ahora, delegamos al agente con contexto específico
        context = (
            "El usuario pregunta sobre el estado de variables del sistema "
            "(temperatura, humedad, tendencia, actuadores, ventiladores, calefactores). "
            "Responde con la información más relevante."
        )
        return self._query_agent(f"{context}\n\nPregunta: {message}")
    
    def handle_otra_consulta(self, message: str) -> str:
        """
        Maneja consultas generales que no corresponden a categorías específicas.
        
        Args:
            message: Consulta del usuario
            
        Returns:
            Respuesta del agente
        """
        logger.info("Ejecutando lógica para otra_consulta")
        return self._query_agent(message)
    
    def _query_agent(self, message: str) -> str:
        """
        Consulta al agente con el system prompt configurado.
        
        Args:
            message: Mensaje a enviar al agente
            
        Returns:
            Respuesta del agente
        """
        try:
            messages = [
                SystemMessage(content=SYSTEM_PROMPT),
                HumanMessage(content=message)
            ]
            
            result = self.agent.invoke({"messages": messages})  # type: ignore
            return result["messages"][-1].content
            
        except Exception as e:
            logger.error(f"Error al consultar agente: {e}")
            return f"❌ Error al invocar el modelo: {str(e)}"
    
    def chat(self, message: str, history) -> str:
        """
        Función principal de chat que clasifica y procesa la consulta.
        
        Args:
            message: Mensaje del usuario
            history: Historial de la conversación
            
        Returns:
            Respuesta generada según la categoría detectada
        """
        logger.info(f"Nueva consulta: {message}")
        
        # 1. Clasificar la consulta
        category = self.classify_query(message)
        logger.info(f"Categoría clasificada: {category}")

        # 2. Ejecutar lógica según categoría
        if category == "corrida_actual":
            return self.handle_corrida_actual()
        elif category == "estado_variables":
            return self.handle_estado_variables(message)
        else:  # otra_consulta
            return self.handle_otra_consulta(message)


def main():
    """Inicializa y lanza la aplicación de Gradio."""
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
            "Explícame el proceso de fermentación del ajo negro",
            "¿Existe alguna corrida activa?",
            "¿Cuál es el estado de la temperatura actual?"
        ],
    ).launch()


if __name__ == "__main__":
    main()
    