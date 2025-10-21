#!/usr/bin/env python3
"""
Script de prueba para verificar la conexión con Ollama desde el devcontainer
"""
import requests
import os

# Intentar diferentes URLs
urls_to_test = [
    "http://localhost:11434",
    "http://host.docker.internal:11434",
    "http://172.17.0.1:11434",  # Gateway de Docker por defecto
]

print("🔍 Verificando conexión con Ollama...\n")

for url in urls_to_test:
    try:
        print(f"Probando: {url}")
        response = requests.get(f"{url}/api/tags", timeout=2)
        if response.status_code == 200:
            print(f"✅ ÉXITO! Ollama está accesible en: {url}")
            models = response.json().get("models", [])
            print(f"   Modelos disponibles: {len(models)}")
            for model in models:
                print(f"      - {model.get('name', 'N/A')}")
            print(f"\n💡 Usa esta URL en tu .env:")
            print(f"   OLLAMA_HOST={url}\n")
            break
        else:
            print(f"❌ No accesible (status: {response.status_code})\n")
    except requests.exceptions.ConnectionError:
        print(f"❌ No se pudo conectar\n")
    except requests.exceptions.Timeout:
        print(f"❌ Timeout\n")
    except Exception as e:
        print(f"❌ Error: {e}\n")
else:
    print("⚠️  No se pudo encontrar Ollama en ninguna URL.")
    print("\nAsegúrate de que:")
    print("1. Ollama está corriendo en el HOST: ollama serve")
    print("2. El puerto 11434 está accesible")
    print("3. Si usas Windows/Mac, Docker Desktop está corriendo")
