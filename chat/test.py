"""
Demo de chat con Gradio usando AutoModel + AutoTokenizer (Transformers) en modo chat.

Dependencias:
  pip install gradio transformers accelerate
  # y PyTorch (CPU o CUDA):
  pip install --index-url https://download.pytorch.org/whl/cpu torch

Ejecución:
  python test.py
"""

# pip install transformers accelerate gradio
import torch
import gradio as gr
from transformers import AutoModelForCausalLM, AutoTokenizer

# ---------------------------------------------------------------------------
# Carga de modelo/tokenizer (global para evitar recarga en cada request)
# ---------------------------------------------------------------------------
MODEL_ID = "Qwen/Qwen2.5-1.5B-Instruct"  # Alternativa liviana: "TinyLlama/TinyLlama-1.1B-Chat-v1.0"
SYSTEM_PROMPT = "Eres un asistente útil y conciso que responde en español."

tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)
model = AutoModelForCausalLM.from_pretrained(
    MODEL_ID,
    device_map="auto",            # "cuda:0" si prefieres forzar GPU
    torch_dtype=torch.bfloat16,   # ajusta según tu GPU/CPU; "auto" también sirve
    # load_in_8bit=True,          # descomenta si necesitas 8-bit (requiere bitsandbytes)
)


def build_messages(history, message):
    """Convierte el historial de Gradio a la plantilla de chat del modelo.

    history: lista de tuplas (user, assistant)
    message: texto actual del usuario
    """
    messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    for user, assistant in history:
        if user:
            messages.append({"role": "user", "content": user})
        if assistant:
            messages.append({"role": "assistant", "content": assistant})
    messages.append({"role": "user", "content": message})
    return messages


def chat_fn(message, history):
    """Función de respuesta para Gradio ChatInterface."""
    messages = build_messages(history, message)

    # Aplica la plantilla de chat del modelo (formatea el prompt)
    text = tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
    inputs = tokenizer(text, return_tensors="pt").to(model.device)

    # Generación
    with torch.no_grad():
        output_ids = model.generate(
            **inputs,
            max_new_tokens=256,
            temperature=0.7,
            top_p=0.9,
            do_sample=True,
        )

    # Extrae solo la parte generada (excluye el prompt)
    prompt_len = inputs["input_ids"].shape[1]
    generated = output_ids[0][prompt_len:]
    reply = tokenizer.decode(generated, skip_special_tokens=True).strip()
    return reply


demo = gr.ChatInterface(
    fn=chat_fn,
    title="Asistente (HF AutoModel)",
    description="Chat en español con modelo open-source de Hugging Face.",
)


if __name__ == "__main__":
    # Lanza el servidor de Gradio. Ajusta server_port si está ocupado.
    demo.launch()