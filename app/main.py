from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.auth.router import router as auth_router
from app.users.router import router as users_router
from app.routers.cars import router as cars_router
from app.routers.chat import router as chat_router
from app.routers.manual_router import router as manual_router
from app.routers.car_brands import router as car_brands_router
from app.routers.catalog import router as catalog_router

app = FastAPI(
    title=settings.APP_NAME,
    debug=settings.DEBUG,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router, prefix="/auth", tags=["auth"])
app.include_router(users_router, prefix="/users", tags=["users"])
app.include_router(cars_router, prefix="/cars", tags=["cars"])
app.include_router(chat_router, prefix="/chat", tags=["chat"])
app.include_router(manual_router, prefix="/manuals", tags=["manuals"])
app.include_router(car_brands_router, prefix="/car-brands", tags=["car-brands"])
app.include_router(catalog_router, prefix="/catalog", tags=["catalog"])
# Дубликат под /cars/catalog — если на проде прокси отдаёт 404 на пути без префикса /cars
app.include_router(catalog_router, prefix="/cars/catalog", tags=["catalog"])


@app.get("/")
async def root():
    return {"message": "FastAPI JWT Auth API"}


@app.get("/health")
async def health():
    return {"status": "ok"}

