BEGIN;

ALTER TABLE public.offers
    ADD COLUMN IF NOT EXISTS title_ar VARCHAR(255) NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS city_ar VARCHAR(255) NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS country_ar VARCHAR(255) NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS description_ar TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS highlights_ar JSONB NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE public.tourist_monuments
    ADD COLUMN IF NOT EXISTS name_ar VARCHAR(255) NOT NULL DEFAULT '';

UPDATE public.offers AS o
SET title_ar = v.title_ar,
    city_ar = v.city_ar,
    country_ar = v.country_ar,
    description_ar = v.description_ar,
    highlights_ar = v.highlights_ar::jsonb
FROM (VALUES
    ('istanbul-dream', 'حلم إسطنبول', 'إسطنبول', 'تركيا', 'اكتشف القصور التاريخية والمساجد والأسواق ومضيق البوسفور.', '["الجامع الأزرق","آيا صوفيا","البازار الكبير"]'),
    ('bali-serenity', 'هدوء بالي', 'بالي', 'إندونيسيا', 'استمتع بالشواطئ الهادئة والمعابد وحقول الأرز وغروب الشمس على الجزيرة.', '["أوبود","تانا لوت","شاطئ سيمينياك"]'),
    ('paris-romance', 'رومانسية باريس', 'باريس', 'فرنسا', 'اكتشف المتاحف والتنزه على ضفاف النهر والمقاهي المحلية ومعالم المدينة.', '["برج إيفل","متحف اللوفر","نهر السين"]'),
    ('dubai-luxury', 'دبي الفاخرة', 'دبي', 'الإمارات', 'اجمع بين العمارة الحديثة وتجارب الصحراء والأمسيات على الواجهة البحرية.', '["برج خليفة","رحلة سفاري صحراوية","نخلة جميرا"]'),
    ('maldives-escape', 'هروب المالديف', 'ماليه', 'المالديف', 'استرخِ بين الشعاب المرجانية والمياه الصافية والإقامة الهادئة في الجزر.', '["الغطس","رحلة بحرية عند الغروب","مشاهدة الدلافين"]'),
    ('tokyo-explorer', 'استكشاف طوكيو', 'طوكيو', 'اليابان', 'استكشف المعابد التقليدية والشوارع المضيئة وأسواق الأطعمة المحلية.', '["معبر شيبويا","معبد سينسو-جي","جبل فوجي"]'),
    ('cairo-pharaohs', 'القاهرة والأهرامات', 'القاهرة', 'مصر', 'قف بجوار أهرامات الجيزة، وتجول في خان الخليلي، واستمتع برحلة نيلية عند الغروب.', '["أهرامات الجيزة","خان الخليلي","رحلة نيلية"]'),
    ('tunis-carthage', 'تونس وقرطاج', 'تونس', 'تونس', 'تجول في أزقة المدينة العتيقة والآثار الرومانية وقرية سيدي بوسعيد الزرقاء والبيضاء.', '["سيدي بوسعيد","قرطاج","مدينة تونس العتيقة"]'),
    ('jeddah-red-sea', 'هروب جدة على البحر الأحمر', 'جدة', 'السعودية', 'استمتع بالكورنيش التاريخي والبلد والأنشطة البحرية في البحر الأحمر قرب المدينة.', '["البلد","الكورنيش","الغوص في البحر الأحمر"]'),
    ('tripoli-heritage', 'عطلة تراث طرابلس', 'طرابلس', 'ليبيا', 'تجول في المدينة القديمة ومتحف السرايا الحمراء والقوس الروماني لماركوس أوريليوس.', '["متحف السرايا الحمراء","المدينة القديمة","قوس ماركوس أوريليوس"]'),
    ('leptis-magna-discovery', 'اكتشاف لبدة الكبرى', 'الخمس', 'ليبيا', 'استكشف مدينة لبدة الرومانية المحفوظة جيداً على البحر المتوسط، ثم زر صبراتة.', '["لبدة الكبرى","صبراتة","ساحل البحر المتوسط"]'),
    ('benghazi-green-mountain', 'بنغازي والجبل الأخضر', 'بنغازي', 'ليبيا', 'استمتع بأجواء المدينة الساحلية والرحلات إلى آثار قورينا ومرفأ أبولونيا.', '["قورينا","أبولونيا","كورنيش بنغازي"]'),
    ('siwa-desert-oasis', 'واحة سيوة الصحراوية', 'سيوة', 'مصر', 'اكتشف بساتين النخيل والبحيرات المالحة والينابيع الحارة وغروب الصحراء الهادئ.', '["واحة سيوة","البحيرات المالحة","غروب الصحراء"]')
) AS v(id, title_ar, city_ar, country_ar, description_ar, highlights_ar)
WHERE o.id = v.id;

UPDATE public.tourist_monuments
SET name_ar = CASE LOWER(TRIM(title))
    WHEN 'royal palace of tripoli' THEN 'القصر الملكي في طرابلس'
    WHEN 'libyan museum' THEN 'المتحف الليبي'
    WHEN 'royal miramare theatre' THEN 'مسرح ميراماري الملكي'
    WHEN 'red castle museum' THEN 'متحف السرايا الحمراء'
    WHEN 'the red castle' THEN 'السرايا الحمراء'
    WHEN 'marcus aurelius arch' THEN 'قوس ماركوس أوريليوس'
    WHEN 'arch of marcus aurelius' THEN 'قوس ماركوس أوريليوس'
    WHEN 'oea' THEN 'أويا'
    ELSE name_ar
END
WHERE LOWER(TRIM(title)) IN (
    'royal palace of tripoli', 'libyan museum', 'royal miramare theatre',
    'red castle museum', 'the red castle', 'marcus aurelius arch',
    'arch of marcus aurelius', 'oea'
);

INSERT INTO public.schema_migrations (version, name)
VALUES ('20261108_arabic_catalog_fields', 'Arabic catalog display fields')
ON CONFLICT (version) DO NOTHING;

COMMIT;
