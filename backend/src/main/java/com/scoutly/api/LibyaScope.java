package com.scoutly.api;

import java.text.Normalizer;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

/**
 * Scoutly is a domestic travel app: flights, hotels and places are limited to
 * Libya. This class is the single source of truth for that scope.
 */
public final class LibyaScope {
    public static final String COUNTRY_CODE = "LY";
    public static final String COUNTRY_NAME = "Libya";
    public static final String OUTSIDE_LIBYA_MESSAGE =
            "Scoutly currently covers destinations inside Libya only.";

    /** Bounding box around Libya (with a small coastal margin). */
    public static final double SOUTH = 19.4;
    public static final double NORTH = 33.6;
    public static final double WEST = 9.2;
    public static final double EAST = 25.4;

    /**
     * Libyan airports with scheduled service. The airport directory's
     * {@code iso_country} column is checked as well; this list keeps flight
     * validation working when the directory is unavailable.
     */
    static final Set<String> KNOWN_AIRPORT_CODES = Set.of(
            "TIP", "MJI", "BEN", "MRA", "SEB", "LAQ", "TOB", "GHT", "AKF", "SRX");

    /**
     * Simplified border of Libya as (latitude, longitude) vertices with a
     * small buffer, used to tell whether a coordinate is inside the country.
     */
    private static final double[][] BORDER = {
            {31.60, 25.20}, {32.15, 24.10}, {32.90, 22.70}, {33.05, 21.60},
            {32.75, 20.60}, {32.15, 19.90}, {30.65, 19.90}, {30.25, 19.30},
            {30.35, 18.40}, {31.25, 16.40}, {32.45, 15.20}, {32.75, 14.20},
            {33.00, 13.10}, {33.00, 12.00}, {33.25, 11.50}, {32.40, 11.30},
            {31.95, 10.65}, {30.30, 9.35}, {28.00, 9.35}, {26.40, 9.40},
            {25.40, 9.80}, {24.50, 10.10}, {23.50, 11.95}, {22.60, 14.20},
            {23.00, 16.00}, {19.50, 24.00}, {20.00, 24.00}, {20.00, 25.00},
            {29.60, 25.00}, {31.00, 25.00},
    };

    private static final Set<String> COUNTRY_ALIASES = Set.of(
            "ly", "lby", "libya", "state of libya", "libyan arab jamahiriya", "ليبيا");

    private LibyaScope() {}

    public static boolean isLibya(String countryOrCode) {
        if (countryOrCode == null) return false;
        return COUNTRY_ALIASES.contains(normalize(countryOrCode));
    }

    public static boolean contains(Double latitude, Double longitude) {
        if (latitude == null || longitude == null
                || !Double.isFinite(latitude) || !Double.isFinite(longitude)) {
            return false;
        }
        if (latitude < SOUTH || latitude > NORTH || longitude < WEST || longitude > EAST) {
            return false;
        }
        boolean inside = false;
        for (int i = 0, j = BORDER.length - 1; i < BORDER.length; j = i++) {
            double latI = BORDER[i][0], lonI = BORDER[i][1];
            double latJ = BORDER[j][0], lonJ = BORDER[j][1];
            if ((latI > latitude) != (latJ > latitude)
                    && longitude < (lonJ - lonI) * (latitude - latI) / (latJ - latI) + lonI) {
                inside = !inside;
            }
        }
        return inside;
    }

    /**
     * Whether a place record (attraction, hotel, airport) is known to be
     * outside Libya. Records with no location data are not rejected, since
     * every search is already limited to Libyan inputs.
     */
    public static boolean isKnownOutside(Map<?, ?> place) {
        if (place == null) return true;
        return locationVerdict(place) == Boolean.FALSE;
    }

    /** Whether a place record is positively located in Libya. */
    public static boolean containsPlace(Map<?, ?> place) {
        return place != null && locationVerdict(place) == Boolean.TRUE;
    }

    /** TRUE inside Libya, FALSE outside, null when the record has no location. */
    private static Boolean locationVerdict(Map<?, ?> place) {
        Double latitude = number(place.get("latitude"));
        Double longitude = number(place.get("longitude"));
        if (latitude == null) latitude = number(place.get("lat"));
        if (longitude == null) longitude = number(place.get("lon"));
        if (longitude == null) longitude = number(place.get("lng"));
        if (latitude != null && longitude != null) return contains(latitude, longitude);
        for (String key : new String[] {"country_code", "country", "iso_country"}) {
            Object value = place.get(key);
            if (value != null && !String.valueOf(value).isBlank()) {
                return isLibya(String.valueOf(value));
            }
        }
        Object location = place.get("location");
        if (location instanceof String text && text.contains(",")) {
            return isLibya(text.substring(text.lastIndexOf(',') + 1));
        }
        return null;
    }

    private static Double number(Object value) {
        if (value instanceof Number number) {
            double result = number.doubleValue();
            return Double.isFinite(result) ? result : null;
        }
        if (value instanceof String text && !text.isBlank()) {
            try {
                double result = Double.parseDouble(text.trim());
                return Double.isFinite(result) ? result : null;
            } catch (NumberFormatException ignored) {
                return null;
            }
        }
        return null;
    }

    private static String normalize(String value) {
        return Normalizer.normalize(value, Normalizer.Form.NFD)
                .replaceAll("\\p{M}+", "")
                .trim()
                .toLowerCase(Locale.ROOT)
                .replaceAll("\\s+", " ");
    }
}
