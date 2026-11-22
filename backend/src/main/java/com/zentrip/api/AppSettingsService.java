package com.zentrip.api;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Admin-managed settings. The USD -> LYD reference rate lives here so an
 * administrator can change it without a release (Frankfurter has no LYD).
 */
@Service
public class AppSettingsService {
    static final String LYD_RATE_KEY = "currency.lyd_per_usd";
    static final BigDecimal DEFAULT_LYD_PER_USD = new BigDecimal("6.4");
    static final BigDecimal MIN_LYD_PER_USD = new BigDecimal("0.1");
    static final BigDecimal MAX_LYD_PER_USD = new BigDecimal("1000");

    private static final Logger LOG = LoggerFactory.getLogger(AppSettingsService.class);
    private static final long CACHE_MILLIS = 60_000;

    private final JdbcTemplate jdbc;
    private BigDecimal cachedLydRate;
    private OffsetDateTime cachedUpdatedAt;
    private long cachedAt;

    public AppSettingsService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** Current USD -> LYD reference rate (cached for a minute). */
    public synchronized BigDecimal lydPerUsd() {
        refreshIfStale();
        return cachedLydRate;
    }

    public synchronized Map<String, Object> lydRate() {
        refreshIfStale();
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("base", "USD");
        body.put("quote", "LYD");
        body.put("rate", cachedLydRate);
        body.put("source", "admin");
        body.put("updated_at", cachedUpdatedAt == null ? null : cachedUpdatedAt.toString());
        return body;
    }

    public synchronized Map<String, Object> updateLydPerUsd(Object rawRate, long adminId) {
        BigDecimal rate;
        try {
            rate = new BigDecimal(String.valueOf(rawRate).trim());
        } catch (NumberFormatException exception) {
            throw new ResponseStatusException(
                    HttpStatus.UNPROCESSABLE_ENTITY, "rate must be a number");
        }
        if (rate.compareTo(MIN_LYD_PER_USD) < 0 || rate.compareTo(MAX_LYD_PER_USD) > 0) {
            throw new ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY,
                    "rate must be between " + MIN_LYD_PER_USD + " and " + MAX_LYD_PER_USD);
        }
        rate = rate.setScale(4, RoundingMode.HALF_UP).stripTrailingZeros();
        jdbc.update("""
                INSERT INTO app_settings (key, value, updated_by, updated_at)
                VALUES (?, ?, ?, NOW())
                ON CONFLICT (key) DO UPDATE
                SET value = EXCLUDED.value,
                    updated_by = EXCLUDED.updated_by,
                    updated_at = EXCLUDED.updated_at
                """, LYD_RATE_KEY, rate.toPlainString(), adminId);
        cachedAt = 0;
        return lydRate();
    }

    private void refreshIfStale() {
        long now = Instant.now().toEpochMilli();
        if (cachedLydRate != null && now - cachedAt < CACHE_MILLIS) return;
        BigDecimal rate = DEFAULT_LYD_PER_USD;
        OffsetDateTime updatedAt = null;
        try {
            List<Map<String, Object>> rows = jdbc.queryForList(
                    "SELECT value, updated_at FROM app_settings WHERE key = ?",
                    LYD_RATE_KEY);
            if (!rows.isEmpty()) {
                BigDecimal stored = new BigDecimal(String.valueOf(rows.getFirst().get("value")));
                if (stored.signum() > 0) rate = stored;
                Object raw = rows.getFirst().get("updated_at");
                if (raw instanceof OffsetDateTime value) {
                    updatedAt = value;
                } else if (raw instanceof java.sql.Timestamp value) {
                    updatedAt = value.toInstant().atOffset(java.time.ZoneOffset.UTC);
                }
            }
        } catch (DataAccessException | NumberFormatException exception) {
            // Table missing (migration not applied) or bad value: keep the default.
            LOG.warn("Using default USD->LYD rate: {}", exception.getMessage());
        }
        cachedLydRate = rate;
        cachedUpdatedAt = updatedAt;
        cachedAt = now;
    }
}
