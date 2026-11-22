BEGIN;

DO $$
BEGIN
    IF to_regclass('public.schema_migrations') IS NULL
       OR to_regclass('public.users') IS NULL
       OR NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'zentrip_api_runtime')
       OR to_regprocedure('public.zentrip_rls_role()') IS NULL THEN
        RAISE EXCEPTION 'Migration 20261122_app_settings requires users and the 20261101_role_access_rls runtime role/helpers';
    END IF;
END
$$;

-- Admin-managed application settings (e.g. the USD -> LYD reference rate).
CREATE TABLE IF NOT EXISTS public.app_settings (
    key TEXT PRIMARY KEY CHECK (key ~ '^[a-z0-9_.]{1,100}$'),
    value TEXT NOT NULL CHECK (length(value) BETWEEN 1 AND 1000),
    updated_by BIGINT REFERENCES public.users(id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO public.app_settings (key, value)
VALUES ('currency.lyd_per_usd', '6.4')
ON CONFLICT (key) DO NOTHING;

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_settings_read ON public.app_settings;
CREATE POLICY app_settings_read
    ON public.app_settings
    FOR SELECT TO zentrip_api_runtime
    USING (TRUE);

DROP POLICY IF EXISTS app_settings_admin_write ON public.app_settings;
CREATE POLICY app_settings_admin_write
    ON public.app_settings
    FOR ALL TO zentrip_api_runtime
    USING (public.zentrip_rls_role() = 'admin')
    WITH CHECK (public.zentrip_rls_role() = 'admin');

GRANT SELECT, INSERT, UPDATE ON public.app_settings TO zentrip_api_runtime;
REVOKE ALL ON public.app_settings FROM PUBLIC, anon, authenticated;

INSERT INTO public.schema_migrations (version, name)
VALUES ('20261122_app_settings', 'app_settings')
ON CONFLICT (version) DO NOTHING;

COMMIT;
