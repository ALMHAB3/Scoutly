package com.scoutly.api;

import org.junit.jupiter.api.Test;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class AppSettingsServiceTest {
    private final JdbcTemplate jdbc = mock(JdbcTemplate.class);
    private final AppSettingsService settings = new AppSettingsService(jdbc);

    @Test
    void usesTheStoredAdminRate() {
        when(jdbc.queryForList(anyString(), eq(AppSettingsService.LYD_RATE_KEY)))
                .thenReturn(List.of(Map.of("value", "7.25")));
        assertEquals(new BigDecimal("7.25"), settings.lydPerUsd());
        assertEquals(new BigDecimal("7.25"), settings.lydRate().get("rate"));
    }

    @Test
    void fallsBackToTheDefaultWhenTheTableIsMissing() {
        when(jdbc.queryForList(anyString(), eq(AppSettingsService.LYD_RATE_KEY)))
                .thenThrow(new DataAccessResourceFailureException("no table"));
        assertEquals(AppSettingsService.DEFAULT_LYD_PER_USD, settings.lydPerUsd());
    }

    @Test
    void rejectsOutOfRangeOrInvalidRates() {
        assertEquals(422, assertThrows(ResponseStatusException.class,
                () -> settings.updateLydPerUsd("0", 1L)).getStatusCode().value());
        assertEquals(422, assertThrows(ResponseStatusException.class,
                () -> settings.updateLydPerUsd("abc", 1L)).getStatusCode().value());
        assertEquals(422, assertThrows(ResponseStatusException.class,
                () -> settings.updateLydPerUsd("5000", 1L)).getStatusCode().value());
        verify(jdbc, never()).update(anyString(), any(), any(), any());
    }

    @Test
    void onlyAdminsCanChangeTheRate() {
        AdminController controller = new AdminController(jdbc, settings);
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setAttribute("authUserId", 7L);
        when(jdbc.queryForObject("SELECT role FROM users WHERE id = ?", String.class, 7L))
                .thenReturn("customer");
        ResponseStatusException denied = assertThrows(ResponseStatusException.class,
                () -> controller.updateLydRate(Map.of("rate", "7"), request));
        assertEquals(403, denied.getStatusCode().value());
        verify(jdbc, never()).update(anyString(), any(), any(), any());

        when(jdbc.queryForObject("SELECT role FROM users WHERE id = ?", String.class, 7L))
                .thenReturn("admin");
        when(jdbc.queryForList(anyString(), eq(AppSettingsService.LYD_RATE_KEY)))
                .thenReturn(List.of(Map.of("value", "7")));
        Map<String, Object> saved = controller.updateLydRate(Map.of("rate", "7.0"), request);
        verify(jdbc).update(anyString(), eq(AppSettingsService.LYD_RATE_KEY), eq("7"), eq(7L));
        assertEquals(new BigDecimal("7"), saved.get("rate"));
    }
}
