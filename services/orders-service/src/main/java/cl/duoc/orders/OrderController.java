package cl.duoc.orders;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Positive;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestClientException;

@RestController
@RequestMapping("/orders")
public class OrderController {

    public record OrderRequest(@Positive long itemId, @Min(1) int quantity) {}

    private final InventoryClient inventory;

    public OrderController(InventoryClient inventory) {
        this.inventory = inventory;
    }

    @PostMapping
    public ResponseEntity<Map<String, Object>> create(@Valid @RequestBody OrderRequest req) {
        Optional<Integer> stock;
        try {
            stock = inventory.getStock(req.itemId());
        } catch (RestClientException e) {
            return ResponseEntity.status(503).body(Map.of("error", "inventory-service no disponible"));
        }
        if (stock.isEmpty()) {
            return ResponseEntity.status(404).body(Map.of("error", "Item no encontrado"));
        }
        if (stock.get() < req.quantity()) {
            return ResponseEntity.status(409).body(Map.of("error", "Stock insuficiente"));
        }
        return ResponseEntity.status(201).body(Map.of(
                "orderId", UUID.randomUUID().toString(),
                "itemId", req.itemId(),
                "quantity", req.quantity(),
                "status", "CREATED"));
    }
}
