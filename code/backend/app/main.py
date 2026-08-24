from fastapi import FastAPI

app = FastAPI(
        title = "Intelligent Expense Tracker API",
        version = "0.1.0",
)

@app.get("/ping")
async def ping():
    return {"message": "pong"}
