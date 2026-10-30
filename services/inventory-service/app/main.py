from fastapi import FastAPI, HTTPException

app = FastAPI(title="inventory-service", version="1.0.0")

ITEMS = {
    1: {"id": 1, "name": "Teclado mecánico", "stock": 25},
    2: {"id": 2, "name": "Mouse inalámbrico", "stock": 0},
    3: {"id": 3, "name": "Monitor 24 pulgadas", "stock": 8},
}


@app.get("/health")
def health():
    return {"status": "UP"}


@app.get("/items")
def list_items():
    return list(ITEMS.values())


@app.get("/items/{item_id}/stock")
def get_stock(item_id: int):
    item = ITEMS.get(item_id)
    if item is None:
        raise HTTPException(status_code=404, detail="Item no encontrado")
    return {"id": item_id, "stock": item["stock"]}
