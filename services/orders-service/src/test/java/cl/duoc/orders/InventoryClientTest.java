package cl.duoc.orders;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.Optional;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.web.client.RestClientException;

class InventoryClientTest {

    private static HttpServer server;
    private static InventoryClient client;

    @BeforeAll
    static void start() throws IOException {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/items/1/stock", ex -> respond(ex, 200, "{\"id\":1,\"stock\":25}"));
        server.createContext("/", ex -> respond(ex, 404, "{\"detail\":\"no\"}"));
        server.start();
        client = new InventoryClient("http://127.0.0.1:" + server.getAddress().getPort());
    }

    @AfterAll
    static void stop() {
        server.stop(0);
    }

    private static void respond(HttpExchange ex, int code, String body) throws IOException {
        byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
        ex.getResponseHeaders().add("Content-Type", "application/json");
        ex.sendResponseHeaders(code, bytes.length);
        try (OutputStream os = ex.getResponseBody()) {
            os.write(bytes);
        }
    }

    @Test
    void devuelveStockDeItemExistente() {
        assertEquals(Optional.of(25), client.getStock(1));
    }

    @Test
    void devuelveVacioSiItemNoExiste() {
        assertTrue(client.getStock(99).isEmpty());
    }

    @Test
    void lanzaExcepcionSiInventarioNoEstaDisponible() {
        InventoryClient caido = new InventoryClient("http://127.0.0.1:1");
        assertThrows(RestClientException.class, () -> caido.getStock(1));
    }
}
