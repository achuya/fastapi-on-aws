from fastapi import FastAPI
from app.routers import users, posts

app = FastAPI(
    title="User Management API",
    description="ユーザーと投稿を管理するREST API",
    version="1.0.0"
)

app.include_router(users.router)
app.include_router(posts.router)


@app.get("/health")
def health_check():
    return {"status": "ok"}