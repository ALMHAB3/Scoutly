package com.scoutly.api;

import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;

import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

class AirportDirectoryServiceTest {
    private final JdbcTemplate jdbc = mock(JdbcTemplate.class);
    private final GeoapifyAirportService geocoder = mock(GeoapifyAirportService.class);
    private final AirportDirectoryService directory = new AirportDirectoryService(
            jdbc, geocoder, mock(OpenTripMapAttractionService.class));

    @Test
    void categoryWithoutLocationDoesNotQueryExternalServices() {
        Map<String, Object> result = directory.search("Nature");
        assertEquals("category", result.get("query_type"));
        assertEquals(List.of(), result.get("airports"));
        verifyNoInteractions(jdbc, geocoder);
    }

    @Test
    void exactCodeReturnsFullAirportMetadata() {
        when(jdbc.queryForList(anyString(), any(Object[].class))).thenReturn(
                List.of(Map.of("code", "MJI", "icao_code", "HLLM", "is_major", true,
                        "iso_country", "LY")));
        Map<String, Object> result = directory.search("MJI");
        assertEquals("airport_code", result.get("query_type"));
        Map<?, ?> airport = (Map<?, ?>) ((List<?>) result.get("airports")).getFirst();
        assertEquals("HLLM", airport.get("icao_code"));
        assertEquals("major", airport.get("priority"));
        verifyNoInteractions(geocoder);
    }

    @Test
    void unmatchedTextReachesGeocoderWithoutSqlFormattingFailure() {
        when(jdbc.queryForObject(anyString(), eq(Integer.class), any(Object[].class)))
                .thenReturn(0);
        when(jdbc.queryForList(anyString(), any(Object[].class))).thenReturn(List.of());
        Map<String, Object> result = directory.search("Eiffel Tower");
        assertEquals("no_match", result.get("query_type"));
        verify(geocoder).resolveLocation("Eiffel Tower", "LY");
    }
}
