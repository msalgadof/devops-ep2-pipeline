package cl.duoc.orders;

import java.util.Optional;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestClient;

@Component
public class InventoryClient {

    public record StockResponse(long id, int stock) {}

    private final RestClient client;

    public InventoryClient(@Value("${inventory.url}") String baseUrl) {
        var factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(2000);
        factory.setReadTimeout(3000);
        this.client = RestClient.builder().baseUrl(baseUrl).requestFactory(factory).build();
    }

    /** Devuelve el stock, o vacío si el item no existe. Lanza RestClientException si A no responde. */
    public Optional<Integer> getStock(long itemId) {
        try {
            StockResponse res = client.get()
                    .uri("/items/{id}/stock", itemId)
                    .retrieve()
                    .body(StockResponse.class);
            return Optional.ofNullable(res).map(StockResponse::stock);
        } catch (HttpClientErrorException.NotFound e) {
            return Optional.empty();
        }
    }
}
