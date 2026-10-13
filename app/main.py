from fastapi import FastAPI

app = FastAPI(title="Origin Hub API")


@app.get("/")
def root() -> dict[str, str]:
    return {"message": "Hello from Origin Hub API"}
