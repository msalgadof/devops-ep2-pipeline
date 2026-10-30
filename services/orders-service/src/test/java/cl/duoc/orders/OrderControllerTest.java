package cl.duoc.orders;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.web.client.RestClientException;

@WebMvcTest(OrderController.class)
class OrderControllerTest {

    @Autowired
    private MockMvc mvc;

    @MockBean
    private InventoryClient inventory;

    private String json(long itemId, int quantity) {
        return "{\"itemId\":" + itemId + ",\"quantity\":" + quantity + "}";
    }

    @Test
    void creaPedidoCuandoHayStock() throws Exception {
        when(inventory.getStock(1L)).thenReturn(Optional.of(25));
        mvc.perform(post("/orders").contentType(MediaType.APPLICATION_JSON).content(json(1, 2)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("CREATED"))
                .andExpect(jsonPath("$.orderId").exists());
    }

    @Test
    void devuelve409CuandoNoHayStockSuficiente() throws Exception {
        when(inventory.getStock(2L)).thenReturn(Optional.of(0));
        mvc.perform(post("/orders").contentType(MediaType.APPLICATION_JSON).content(json(2, 1)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error").value("Stock insuficiente"));
    }

    @Test
    void devuelve404CuandoItemNoExiste() throws Exception {
        when(inventory.getStock(99L)).thenReturn(Optional.empty());
        mvc.perform(post("/orders").contentType(MediaType.APPLICATION_JSON).content(json(99, 1)))
                .andExpect(status().isNotFound());
    }

    @Test
    void devuelve503CuandoInventarioNoResponde() throws Exception {
        when(inventory.getStock(1L)).thenThrow(new RestClientException("caido"));
        mvc.perform(post("/orders").contentType(MediaType.APPLICATION_JSON).content(json(1, 1)))
                .andExpect(status().isServiceUnavailable());
    }

    @Test
    void devuelve400CuandoLaCantidadEsInvalida() throws Exception {
        mvc.perform(post("/orders").contentType(MediaType.APPLICATION_JSON).content(json(1, 0)))
                .andExpect(status().isBadRequest());
    }
}
