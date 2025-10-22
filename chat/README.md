# 1. Instalar dependencias (si hace falta)
cd /workspaces/proyecto/chat
.venv/bin/python -m pip install -r requirements.txt

# 2. Asegurarse de que Ollama está corriendo
docker run -d --gpus=all -v ollama:/root/.ollama -p 11434:11434 --name ollama ollama/ollama

# 3. Verificar que el modelo está descargado
docker exec -it ollama ollama run llama3.2:latest
docker exec -it ollama ollama run qwen3:4b

# 4. Ejecutar la aplicación
.venv/bin/python main.py