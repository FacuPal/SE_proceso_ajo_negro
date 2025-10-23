# Prompt de clasificación de categorías
CLASSIFICATION_PROMPT = """Sos un asistente que debe analizar una consulta realizada por el usuario y clasificarla en una de las siguientes categorías relacionadas al proceso de fermentación de ajo negro:

corrida_actual: El usuario consulta si existe alguna corrida (proceso/lote/ejecución) activa. Por ejemplo: "¿Existe alguna corrida activa?"
estado_variables: El usuario consulta el estado de las variables del sistema en tiempo real. Las variables que maneja el sistema son temperatura, humedad, tendencia, actuadores, ventiladores, calefactores. Por ejemplo: "¿Cuál es el estado actual de la corrida?"
otra_consulta: Cualquier consulta que no corresponda a ninguna de las categorías anteriores, por defecto encaja en esta categoría.

Debes contestar únicamente con un JSON que respete el siguiente schema, sin agregar información adicional:
{{"category": "<categoría>"}}

Pregunta: {question}"""