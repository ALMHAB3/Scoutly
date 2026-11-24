package com.scoutly.api;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;

class HotelDestinationCatalogServiceTest {
    private final JdbcTemplate jdbc = mock(JdbcTemplate.class);
    private final GeoapifyAirportService geoapify = mock(GeoapifyAirportService.class);
    private final HotelDestinationCatalogService service =
            new HotelDestinationCatalogService(jdbc, geoapify);

    @Test
    void returnsEnglishAndArabicNamesFromTheLocalCatalog() {
        when(jdbc.queryForObject(
                eq("SELECT to_regclass('public.hotel_destinations') IS NOT NULL"),
                eq(Boolean.class)))
                .thenReturn(true);
        when(jdbc.queryForList(anyString(), any(Object[].class)))
                .thenReturn(List.of(Map.of(
                        "destination_type", "city",
                        "destination_code", "TIP",
                        "name_en", "Tripoli",
                        "name_ar", "طرابلس",
                        "country_code", "LY",
                        "country_name_en", "Libya",
                        "country_name_ar", "ليبيا",
                        "latitude", 32.8872,
                        "longitude", 13.1913)));

        List<Map<String, Object>> suggestions = service.suggest("tr", "ar");

        assertEquals(1, suggestions.size());
        assertEquals("Tripoli", suggestions.getFirst().get("name"));
        assertEquals("طرابلس", suggestions.getFirst().get("localized_name"));
        assertEquals("TIP", suggestions.getFirst().get("destination_code"));
        assertEquals("LY", suggestions.getFirst().get("country_code"));
        assertEquals("ليبيا",
                suggestions.getFirst().get("country_name_localized"));
    }

    @Test
    void usesAResolvedCityInsteadOfAnOpenTripMapGeonameOrHardcodedMatch() {
        when(jdbc.queryForObject(
                eq("SELECT to_regclass('public.hotel_destinations') IS NOT NULL"),
                eq(Boolean.class)))
                .thenReturn(false);
        when(geoapify.resolveCity("Ghadames", "LY"))
                .thenReturn(new GeoapifyAirportService.GeocodedPlace(
                        "Ghadames",
                        "Ghadames",
                        "Libya",
                        "ly",
                        "Nalut",
                        "Ghadames, Libya",
                        "city",
                        "geoapify-ghadames",
                        null,
                        30.1337,
                        9.5007));

        List<Map<String, Object>> suggestions = service.suggest("Ghadames", "en");

        assertEquals(1, suggestions.size());
        assertEquals("Ghadames", suggestions.getFirst().get("name"));
        assertEquals("LY", suggestions.getFirst().get("country_code"));
        assertEquals("geoapify-ghadames", suggestions.getFirst().get("place_id"));
        assertEquals(30.1337, suggestions.getFirst().get("latitude"));
        assertEquals(9.5007, suggestions.getFirst().get("longitude"));
    }

    @Test
    void doesNotInventAPopularDestinationWhenGeocodingReturnsNothing() {
        when(jdbc.queryForObject(
                eq("SELECT to_regclass('public.hotel_destinations') IS NOT NULL"),
                eq(Boolean.class)))
                .thenReturn(false);
        when(geoapify.resolveCity(anyString(), anyString())).thenReturn(null);

        assertEquals(List.of(), service.suggest("Somewhere", "en"));
    }

    @Test
    void rejectsCitiesOutsideLibya() {
        when(jdbc.queryForObject(
                eq("SELECT to_regclass('public.hotel_destinations') IS NOT NULL"),
                eq(Boolean.class)))
                .thenReturn(false);
        when(geoapify.resolveCity("Zürich", "LY"))
                .thenReturn(new GeoapifyAirportService.GeocodedPlace(
                        "Zurich", "Zurich", "Switzerland", "CH", "Zurich",
                        "Zurich, Switzerland", "city", "geoapify-zurich",
                        null, 47.3769, 8.5417));

        List<Map<String, Object>> suggestions = service.suggest("Zürich", "en");

        assertEquals(List.of(), suggestions);
    }
}
