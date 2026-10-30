import pytest
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health_devuelve_up():
    res = client.get("/health")
    assert res.status_code == 200
    assert res.json() == {"status": "UP"}


def test_list_items_devuelve_catalogo():
    res = client.get("/items")
    assert res.status_code == 200
    assert len(res.json()) == 3


@pytest.mark.parametrize("item_id, stock", [(1, 25), (2, 0), (3, 8)])
def test_stock_de_items_existentes(item_id, stock):
    res = client.get(f"/items/{item_id}/stock")
    assert res.status_code == 200
    assert res.json() == {"id": item_id, "stock": stock}


def test_stock_de_item_inexistente_devuelve_404():
    res = client.get("/items/99/stock")
    assert res.status_code == 404


def test_stock_con_id_invalido_devuelve_422():
    res = client.get("/items/abc/stock")
    assert res.status_code == 422
