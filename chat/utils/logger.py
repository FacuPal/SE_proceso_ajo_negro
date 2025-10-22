"""
Configuración centralizada del logger para todo el proyecto.
"""
from logging import getLogger, basicConfig, INFO, Logger

# Configurar el logging a nivel de módulo
basicConfig(
    level=INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)

def get_logger(name: str) -> Logger:
    """
    Obtiene un logger configurado para el módulo especificado.
    
    Args:
        name: Nombre del módulo (típicamente __name__)
        
    Returns:
        Logger configurado
        
    Example:
        >>> from utils.logger import get_logger
        >>> logger = get_logger(__name__)
        >>> logger.info("Mensaje de prueba")
    """
    return getLogger(name)
