package com.scoutly.api;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

class LibyaScopeTest {

    @Test
    void libyanCitiesAreInside() {
        assertTrue(LibyaScope.contains(32.8872, 13.1913)); // Tripoli
        assertTrue(LibyaScope.contains(32.1167, 20.0667)); // Benghazi
        assertTrue(LibyaScope.contains(32.3754, 15.0925)); // Misrata
        assertTrue(LibyaScope.contains(27.0377, 14.4283)); // Sebha
        assertTrue(LibyaScope.contains(30.1337, 9.5007));  // Ghadames
        assertTrue(LibyaScope.contains(24.9640, 10.1728)); // Ghat
        assertTrue(LibyaScope.contains(24.1833, 23.3000)); // Kufra
        assertTrue(LibyaScope.contains(32.0836, 23.9764)); // Tobruk
        assertTrue(LibyaScope.contains(32.6383, 14.2906)); // Leptis Magna
    }

    @Test
    void neighbouringAndDistantCitiesAreOutside() {
        assertFalse(LibyaScope.contains(36.8065, 10.1815)); // Tunis
        assertFalse(LibyaScope.contains(32.9297, 10.4518)); // Tataouine, Tunisia
        assertFalse(LibyaScope.contains(33.8076, 10.8451)); // Djerba, Tunisia
        assertFalse(LibyaScope.contains(29.2032, 25.5195)); // Siwa, Egypt
        assertFalse(LibyaScope.contains(30.0444, 31.2357)); // Cairo
        assertFalse(LibyaScope.contains(24.5534, 9.4847));  // Djanet, Algeria
        assertFalse(LibyaScope.contains(48.8566, 2.3522));  // Paris
        assertFalse(LibyaScope.contains(null, 13.0));
    }

    @Test
    void recognisesLibyaByCodeOrName() {
        assertTrue(LibyaScope.isLibya("LY"));
        assertTrue(LibyaScope.isLibya("ly"));
        assertTrue(LibyaScope.isLibya(" Libya "));
        assertTrue(LibyaScope.isLibya("ليبيا"));
        assertFalse(LibyaScope.isLibya("Lebanon"));
        assertFalse(LibyaScope.isLibya("TN"));
    }

    @Test
    void placesWithoutLocationAreNotRejected() {
        Map<String, Object> unknown = new HashMap<>(Map.of("name", "Old medina"));
        assertFalse(LibyaScope.isKnownOutside(unknown));
        assertTrue(LibyaScope.isKnownOutside(Map.of("country", "France")));
        assertTrue(LibyaScope.isKnownOutside(Map.of("latitude", 41.0, "longitude", 28.9)));
        assertFalse(LibyaScope.isKnownOutside(Map.of("location", "Sabratha, Libya")));
    }

    @Test
    void responseFilterDropsForeignPlaces() {
        Map<String, Object> response = new HashMap<>();
        response.put("attractions", List.of(
                Map.of("name", "Leptis Magna", "latitude", 32.6383, "longitude", 14.2906),
                Map.of("name", "Eiffel Tower", "latitude", 48.8584, "longitude", 2.2945)));
        response.put("total_count", 2);

        Map<String, Object> filtered = ApiController.libyaOnly(response, "attractions");

        List<?> attractions = (List<?>) filtered.get("attractions");
        assertEquals(1, attractions.size());
        assertEquals("Leptis Magna", ((Map<?, ?>) attractions.getFirst()).get("name"));
        assertEquals(1, filtered.get("total_count"));
    }
}
