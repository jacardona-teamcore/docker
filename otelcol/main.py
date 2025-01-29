from fastapi import FastAPI

# Crear una instancia de FastAPI
app = FastAPI()

# Definir una ruta básica
@app.get("/")
def read_root():
    return {"message": "¡Hola, mundo!"}

# Definir una ruta con parámetros
@app.get("/saludo/{nombre}")
def saludar(nombre: str):
    return {"message": f"¡Hola, {nombre}!"}

# Definir una ruta para sumar dos números
@app.get("/sumar")
def sumar(a: int, b: int):
    return {"resultado": a + b}