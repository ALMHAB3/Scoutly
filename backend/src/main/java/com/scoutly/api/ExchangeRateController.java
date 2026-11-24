package com.scoutly.api;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
public class ExchangeRateController {
    private final ExchangeRateService rates;
    private final AppSettingsService settings;

    public ExchangeRateController(ExchangeRateService rates, AppSettingsService settings) {
        this.rates = rates;
        this.settings = settings;
    }

    @GetMapping("/api/exchange-rates")
    public Map<String, Object> latest() {
        return rates.latest();
    }

    /** Admin-managed USD -> LYD reference rate (always available). */
    @GetMapping("/api/exchange-rates/lyd")
    public Map<String, Object> lyd() {
        return settings.lydRate();
    }
}
