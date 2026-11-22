#!/usr/bin/env node
"use strict";

/**
 * Read-only live Supabase schema export.
 * Produces an editable Word ER diagram (native Word drawing canvases,
 * shapes, connectors and tables) plus a complete column dictionary.
 */

const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");
const {
  AlignmentType,
  BorderStyle,
  Document,
  HeadingLevel,
  PageBreak,
  PageOrientation,
  Paragraph,
  Packer,
  ShadingType,
  Table,
  TableCell,
  TableRow,
  TextRun,
  WidthType,
} = require("docx");
const { ShapeCanvasRun } = require("docx/shapes");

const ROOT = path.resolve(__dirname, "..");
const OUTPUT = path.join(ROOT, "generated-artifacts", "ZenTrip-Supabase-Database-Diagram.docx");
const ARABIC_OUTPUT = path.join(ROOT, "generated-artifacts", "Zentrip-Supabase-Database-Guide-Ar.docx");
const COLORS = {
  ink: "24364B",
  muted: "5F7183",
  blue: "466B91",
  border: "C9D5E1",
  paper: "F5F8FB",
  white: "FFFFFF",
  account: { fill: "EEF4FB", line: "7997B7", accent: "315B85" },
  partner: { fill: "F3F0FA", line: "9284B7", accent: "65528B" },
  booking: { fill: "EEF6F5", line: "77A49D", accent: "39766D" },
  destination: { fill: "F4F6EA", line: "A1AA6E", accent: "69743A" },
  system: { fill: "F3F4F6", line: "9AA3AD", accent: "59636F" },
};

const SCHEMA_SQL = `
SELECT json_build_object(
  'database', current_database(),
  'schema', current_schema(),
  'serverVersion', current_setting('server_version'),
  'tables', (
    SELECT COALESCE(json_agg(
      json_build_object(
        'name', t.table_name,
        'columns', (
          SELECT COALESCE(json_agg(json_build_object(
            'name', c.column_name,
            'udt', c.udt_name,
            'nullable', c.is_nullable = 'YES',
            'default', c.column_default,
            'charLength', c.character_maximum_length,
            'precision', c.numeric_precision,
            'scale', c.numeric_scale
          ) ORDER BY c.ordinal_position), '[]'::json)
          FROM information_schema.columns c
          WHERE c.table_schema = t.table_schema AND c.table_name = t.table_name
        )
      ) ORDER BY t.table_name
    ), '[]'::json)
    FROM information_schema.tables t
    WHERE t.table_schema = 'public' AND t.table_type = 'BASE TABLE'
  ),
  'constraints', (
    SELECT COALESCE(json_agg(json_build_object(
      'table', tc.table_name,
      'name', tc.constraint_name,
      'type', tc.constraint_type,
      'columns', (
        SELECT COALESCE(json_agg(k.column_name ORDER BY k.ordinal_position), '[]'::json)
        FROM information_schema.key_column_usage k
        WHERE k.constraint_schema = tc.constraint_schema
          AND k.constraint_name = tc.constraint_name
          AND k.table_name = tc.table_name
      )
    ) ORDER BY tc.table_name, tc.constraint_type, tc.constraint_name), '[]'::json)
    FROM information_schema.table_constraints tc
    WHERE tc.table_schema = 'public' AND tc.constraint_type IN ('PRIMARY KEY', 'UNIQUE')
  ),
  'foreignKeys', (
    SELECT COALESCE(json_agg(json_build_object(
      'table', child.relname,
      'name', pc.conname,
      'refSchema', parent_schema.nspname,
      'refTable', parent.relname,
      'pairs', (
        SELECT json_agg(json_build_object(
          'column', child_column.attname,
          'refColumn', parent_column.attname
        ) ORDER BY key_pair.ordinality)
        FROM unnest(pc.conkey, pc.confkey) WITH ORDINALITY
          AS key_pair(child_attnum, parent_attnum, ordinality)
        JOIN pg_attribute child_column
          ON child_column.attrelid = pc.conrelid AND child_column.attnum = key_pair.child_attnum
        JOIN pg_attribute parent_column
          ON parent_column.attrelid = pc.confrelid AND parent_column.attnum = key_pair.parent_attnum
      ),
      'updateRule', CASE pc.confupdtype
        WHEN 'a' THEN 'NO ACTION' WHEN 'r' THEN 'RESTRICT' WHEN 'c' THEN 'CASCADE'
        WHEN 'n' THEN 'SET NULL' WHEN 'd' THEN 'SET DEFAULT' END,
      'deleteRule', CASE pc.confdeltype
        WHEN 'a' THEN 'NO ACTION' WHEN 'r' THEN 'RESTRICT' WHEN 'c' THEN 'CASCADE'
        WHEN 'n' THEN 'SET NULL' WHEN 'd' THEN 'SET DEFAULT' END
    ) ORDER BY child.relname, pc.conname), '[]'::json)
    FROM pg_constraint pc
    JOIN pg_class child ON child.oid = pc.conrelid
    JOIN pg_namespace child_schema ON child_schema.oid = child.relnamespace
    JOIN pg_class parent ON parent.oid = pc.confrelid
    JOIN pg_namespace parent_schema ON parent_schema.oid = parent.relnamespace
    WHERE pc.contype = 'f' AND child_schema.nspname = 'public'
  ),
  'routines', (
    SELECT COALESCE(json_agg(json_build_object('name', p.proname) ORDER BY p.proname), '[]'::json)
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prokind = 'f'
      AND p.proname IN (
        'current_app_user_id',
        'set_updated_at',
        'zentrip_adjust_listing_inventory',
        'zentrip_lock_flight_listing',
        'zentrip_register_user_push_token',
        'zentrip_rls_user_id',
        'zentrip_rls_role',
        'zentrip_rls_partner_id'
      )
  ),
  'rowSecurity', (
    SELECT COALESCE(json_agg(json_build_object(
      'table', c.relname,
      'enabled', c.relrowsecurity,
      'forced', c.relforcerowsecurity
    ) ORDER BY c.relname), '[]'::json)
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relkind = 'r'
  )
)::text;
`;

function pgEnvironment() {
  const raw = process.env.SUPABASE_DB_URL;
  if (!raw) throw new Error("SUPABASE_DB_URL is not configured in Replit Secrets.");
  const url = new URL(raw.replace(/^jdbc:/, ""));
  if (!["postgres:", "postgresql:"].includes(url.protocol) || !url.hostname) {
    throw new Error("SUPABASE_DB_URL must be a PostgreSQL or JDBC PostgreSQL URL.");
  }
  const env = { ...process.env };
  env.PGHOST = url.hostname;
  env.PGPORT = url.port || "5432";
  env.PGUSER = process.env.SUPABASE_DB_USER
    || decodeURIComponent(url.username)
    || "postgres";
  env.PGPASSWORD = decodeURIComponent(url.password)
    || process.env.SUPABASE_DB_PASSWORD
    || "";
  env.PGDATABASE = decodeURIComponent(url.pathname.replace(/^\/+/, "")) || "postgres";
  env.PGSSLMODE = url.searchParams.get("sslmode") || "require";
  const channelBinding = url.searchParams.get("channelBinding")
    || url.searchParams.get("channel_binding");
  if (channelBinding) env.PGCHANNELBINDING = channelBinding;
  env.PGAPPNAME = "zentrip-schema-diagram-readonly";
  // Enforce read-only mode at the PostgreSQL session level, as well as using SELECT only.
  env.PGOPTIONS = "-c default_transaction_read_only=on";
  return env;
}

function readLiveSchema() {
  const env = pgEnvironment();
  let result;
  try {
    result = execFileSync(
      "psql",
      ["-X", "-A", "-t", "-v", "ON_ERROR_STOP=1", "-P", "pager=off", "-c", SCHEMA_SQL],
      { cwd: ROOT, env, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] },
    ).trim();
  } catch (error) {
    if (error.code === "ENOENT") throw new Error("psql is required to read the Supabase schema.");
    const detail = String(error.stderr || "")
      .replace(/password authentication failed for user .+/gi, "password authentication failed for user [redacted]")
      .replace(/(user|host|database|dbname)=\S+/gi, "$1=[redacted]")
      .split(/\r?\n/)
      .filter(Boolean)
      .slice(-2)
      .join(" ");
    throw new Error(`Read-only Supabase schema query failed (psql exit ${error.status ?? "unknown"}). ${detail}`);
  }
  if (!result.startsWith("{")) {
    throw new Error("Supabase returned an unexpected schema metadata response.");
  }
  const schema = JSON.parse(result);
  schema.tables = schema.tables || [];
  schema.constraints = schema.constraints || [];
  schema.foreignKeys = schema.foreignKeys || [];
  schema.routines = schema.routines || [];
  schema.rowSecurity = schema.rowSecurity || [];
  if (!schema.tables.length) throw new Error("The public schema contains no base tables.");
  return schema;
}

function postgresType(column) {
  const simple = {
    int2: "smallint",
    int4: "integer",
    int8: "bigint",
    float4: "real",
    float8: "double precision",
    bpchar: "char",
    timestamptz: "timestamptz",
    timestamp: "timestamp",
    bool: "boolean",
  };
  if (column.udt === "varchar" && column.charLength) return `varchar(${column.charLength})`;
  if (column.udt === "numeric" && column.precision) {
    return `numeric(${column.precision},${column.scale || 0})`;
  }
  return simple[column.udt] || column.udt;
}

function prepareSchema(schema) {
  const constraints = new Map();
  for (const item of schema.constraints) {
    const key = `${item.table}:${item.type}`;
    if (!constraints.has(key)) constraints.set(key, []);
    constraints.get(key).push(item);
  }
  const foreignByTable = new Map();
  for (const fk of schema.foreignKeys) {
    if (!foreignByTable.has(fk.table)) foreignByTable.set(fk.table, []);
    foreignByTable.get(fk.table).push(fk);
  }
  for (const table of schema.tables) {
    table.primaryKeys = (constraints.get(`${table.name}:PRIMARY KEY`) || [])
      .flatMap((item) => item.columns);
    table.uniqueConstraints = constraints.get(`${table.name}:UNIQUE`) || [];
    table.foreignKeys = foreignByTable.get(table.name) || [];
    table.columns = table.columns.map((column) => {
      const keyFlags = [];
      if (table.primaryKeys.includes(column.name)) keyFlags.push("PK");
      for (const unique of table.uniqueConstraints) {
        if (unique.columns.length === 1 && unique.columns[0] === column.name) {
          keyFlags.push("UQ");
        } else if (unique.columns.length > 1 && unique.columns.includes(column.name)) {
          keyFlags.push(`UQ (${unique.columns.join(", ")})`);
        }
      }
      for (const fk of table.foreignKeys) {
        const pair = fk.pairs.find((entry) => entry.column === column.name);
        const refName = fk.refSchema && fk.refSchema !== "public"
          ? `${fk.refSchema}.${fk.refTable}`
          : fk.refTable;
        if (pair) keyFlags.push(`FK → ${refName}.${pair.refColumn}`);
      }
      return { ...column, displayType: postgresType(column), keyFlags };
    });
  }
  return schema;
}

function paragraph(text, options = {}) {
  const run = new TextRun({
    text: String(text ?? ""),
    font: "Arial",
    size: options.size || 19,
    bold: Boolean(options.bold),
    color: options.color || COLORS.ink,
  });
  return new Paragraph({
    heading: options.heading,
    alignment: options.alignment,
    bidirectional: Boolean(options.rtl),
    spacing: { before: options.before || 0, after: options.after ?? 100 },
    keepNext: options.keepNext,
    children: [run],
  });
}

function cell(text, { header = false, width = 0 } = {}) {
  return new TableCell({
    width: width ? { size: width, type: WidthType.DXA } : undefined,
    shading: {
      fill: header ? "E8EEF4" : COLORS.white,
      type: ShadingType.CLEAR,
    },
    margins: { top: 55, bottom: 55, left: 90, right: 90 },
    borders: Object.fromEntries(["top", "bottom", "left", "right"].map((side) => [
      side,
      { style: BorderStyle.SINGLE, size: 3, color: COLORS.border },
    ])),
    children: [paragraph(text, {
      size: header ? 17 : 16,
      bold: header,
      color: header ? COLORS.ink : COLORS.muted,
      after: 0,
    })],
  });
}

function dataTable(rows, widths) {
  return new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    columnWidths: widths,
    rows: rows.map((row, index) => new TableRow({
      tableHeader: index === 0,
      children: row.map((value, column) => cell(value, {
        header: index === 0,
        width: widths[column],
      })),
    })),
  });
}

function keySummary(table) {
  const primary = table.primaryKeys.length ? table.primaryKeys.join(", ") : "none declared";
  const fks = table.foreignKeys.flatMap((fk) =>
    fk.pairs.map((pair) => `${pair.column} → ${fk.refTable}.${pair.refColumn}`));
  return { primary, fks };
}

function foreignKeyIsUnique(table, fk) {
  const foreignColumns = fk.pairs.map((pair) => pair.column).sort();
  const matches = (columns) => {
    const sorted = [...columns].sort();
    return sorted.length === foreignColumns.length
      && sorted.every((column, index) => column === foreignColumns[index]);
  };
  return matches(table.primaryKeys)
    || table.uniqueConstraints.some((constraint) => matches(constraint.columns));
}

function entityShape(table, id, x, y, palette) {
  const { primary, fks } = keySummary(table);
  const lines = [
    new Paragraph({
      spacing: { before: 0, after: 55 },
      children: [new TextRun({
        text: table.name,
        font: "Arial",
        size: 22,
        bold: true,
        color: palette.accent,
      })],
    }),
    new Paragraph({
      spacing: { before: 0, after: 35 },
      children: [new TextRun({
        text: `PK  ${primary}`,
        font: "Arial",
        size: 16,
        bold: true,
        color: COLORS.ink,
      })],
    }),
  ];
  const visibleFks = fks.slice(0, 3);
  for (const fk of visibleFks) {
    lines.push(new Paragraph({
      spacing: { before: 0, after: 20 },
      children: [new TextRun({ text: `FK  ${fk}`, font: "Arial", size: 13, color: COLORS.muted })],
    }));
  }
  if (fks.length > visibleFks.length) {
    lines.push(new Paragraph({
      spacing: { before: 0, after: 0 },
      children: [new TextRun({
        text: `+ ${fks.length - visibleFks.length} more FK`,
        font: "Arial",
        size: 13,
        color: COLORS.muted,
        italics: true,
      })],
    }));
  }
  return {
    id,
    type: "roundedRectangle",
    transformation: { offset: { left: x, top: y }, width: 285, height: 112 },
    fill: palette.fill,
    line: { color: palette.line, width: 1.2 },
    children: lines,
    textOptions: {
      verticalAlignment: "top",
      margins: { top: 6, right: 8, bottom: 4, left: 8 },
      wrap: true,
      shrinkTextOnOverflow: true,
    },
    altText: { title: table.name, description: `Supabase table ${table.name}, primary key ${primary}` },
  };
}

function externalShape(id, label, x, y, palette) {
  return {
    id,
    type: "roundedRectangle",
    transformation: { offset: { left: x, top: y }, width: 285, height: 82 },
    fill: "F8FAFC",
    line: { color: palette.line, width: 1.2, dash: "dash" },
    children: [
      new Paragraph({
        alignment: AlignmentType.CENTER,
        spacing: { before: 8, after: 0 },
        children: [new TextRun({ text: label, font: "Arial", size: 19, bold: true, color: palette.accent })],
      }),
    ],
    textOptions: { verticalAlignment: "center", margins: { top: 4, right: 6, bottom: 4, left: 6 } },
    altText: { title: label, description: "Shared entity; full fields are shown in another diagram page." },
  };
}

const PAGES = [
  {
    title: "Identity and account data",
    titleAr: "الحسابات والهوية",
    note: "User-owned data is connected through users.id. password_reset_codes is keyed by email and has no declared foreign key.",
    noteAr: "ترتبط بيانات الحساب بالمستخدم عبر users.id. جدول password_reset_codes يعتمد البريد مفتاحاً أساسياً ولا يملك مفتاحاً أجنبياً إلى users.",
    palette: COLORS.account,
    externalEntries: [
      { schemaTable: "auth.users", id: "external_auth_users", label: "auth.users (Supabase Auth)", x: 20, y: 18 },
    ],
    entries: [
      ["users", 337, 18],
      ["api_tokens", 20, 175],
      ["user_profiles", 337, 175],
      ["travel_preferences", 654, 175],
      ["ai_chat_messages", 20, 350],
      ["password_reset_codes", 654, 350],
    ],
  },
  {
    title: "Saved data and communication",
    titleAr: "المحفوظات والتنبيهات والتواصل",
    note: "These tables hold account-scoped data. user_reviews.item_id and item_type identify different review targets at application level, not through a foreign key.",
    noteAr: "تحفظ هذه الجداول بيانات مرتبطة بالحساب. يحدد user_reviews.item_id وitem_type العنصر المقيّم على مستوى التطبيق، دون مفتاح أجنبي مباشر.",
    palette: COLORS.account,
    entries: [
      ["users", 337, 18],
      ["user_favorites", 20, 175],
      ["user_price_alerts", 337, 175],
      ["user_settings", 654, 175],
      ["user_push_tokens", 20, 350],
      ["user_notifications", 337, 350],
      ["user_reviews", 654, 350],
    ],
  },
  {
    title: "Partner marketplace and offers",
    titleAr: "الشركاء والمخزون والعروض",
    note: "users.partner_id links partner accounts to partners. Each partner owns inventory rows in partner_listings; offers may optionally reference a flight listing.",
    noteAr: "يربط users.partner_id حساب الشريك بسجل partners، ويرتبط مخزون كل شريك بجدول partner_listings. ويمكن للعرض ربط رحلة اختيارية من المخزون.",
    palette: COLORS.partner,
    entries: [
      ["users", 20, 45],
      ["partners", 337, 45],
      ["partner_listings", 654, 45],
      ["offers", 20, 300],
      ["offer_catalog_metadata", 337, 300],
      ["legacy_attraction_partner_reviews", 654, 300],
    ],
  },
  {
    title: "Trips, flights and bookings",
    titleAr: "الرحلات والحجوزات والطيران",
    note: "Solid connectors represent declared PostgreSQL foreign keys. A 1:N label means one referenced row may be linked by multiple child rows.",
    noteAr: "تمثل الخطوط العلاقات المفروضة بمفاتيح PostgreSQL الأجنبية. تعني 1:N أن السجل الواحد قد يرتبط بعدة سجلات تابعة.",
    palette: COLORS.booking,
    entries: [
      ["users", 20, 18],
      ["partners", 337, 18],
      ["partner_listings", 654, 18],
      ["trips", 20, 175],
      ["bookings", 337, 175],
      ["flight_seat_holds", 654, 175],
      ["payment_attempts", 20, 350],
      ["transfers", 337, 350],
      ["transfer_schedules", 654, 350],
    ],
  },
  {
    title: "Attractions and landmark catalog",
    titleAr: "المعالم والسجل الجغرافي",
    note: "The curated tourist_monuments catalog is distinct from the provider-backed landmark_places catalog. Visit counters attach only to tourist_monuments.",
    noteAr: "يختلف سجل tourist_monuments المُدار داخل التطبيق عن landmark_places المستورد من مزودي الأماكن. وترتبط عدادات الزيارة بسجل tourist_monuments فقط.",
    palette: COLORS.destination,
    entries: [
      ["tourist_monuments", 337, 18],
      ["attraction_visit_counts", 20, 175],
      ["attraction_visit_dedup", 654, 175],
      ["landmark_places", 337, 175],
      ["landmark_place_aliases", 20, 350],
      ["landmark_merge_candidates", 337, 350],
      ["landmark_search_areas", 654, 350],
    ],
  },
  {
    title: "Search reference data and migration history",
    titleAr: "بيانات البحث وسجل الترحيلات",
    note: "These lookup and tracking tables have no application-level foreign-key links in the live schema, except the external auth.users reference described in the report.",
    noteAr: "تعمل هذه الجداول كبيانات مرجعية وسجل للتحديثات. ويُشرح في التقرير الربط الخارجي الاختياري مع auth.users.",
    palette: COLORS.system,
    entries: [
      ["airports", 20, 18],
      ["hotel_destinations", 337, 18],
      ["schema_migrations", 654, 18],
    ],
  },
];

function diagramPage(spec, schema, tablesByName, pageIndex) {
  const children = [];
  const included = new Set(spec.entries.map(([name]) => name));
  const ids = new Map();
  for (const [name, x, y] of spec.entries) {
    const table = tablesByName.get(name);
    if (!table) throw new Error(`Expected Supabase table is missing: ${name}`);
    const id = `p${pageIndex}_${name}`;
    ids.set(name, id);
    children.push(entityShape(table, id, x, y, spec.palette));
  }
  for (const external of spec.externalEntries || []) {
    children.push(externalShape(
      `p${pageIndex}_${external.id}`,
      external.label,
      external.x,
      external.y,
      spec.palette,
    ));
  }

  for (const fk of schema.foreignKeys) {
    if (!included.has(fk.table)) continue;
    if (fk.refSchema && fk.refSchema !== "public") {
      const external = (spec.externalEntries || []).find(
        (item) => item.schemaTable === `${fk.refSchema}.${fk.refTable}`,
      );
      if (!external) continue;
      children.push({
        type: "connector",
        from: { id: `p${pageIndex}_${external.id}`, side: "right" },
        to: { id: ids.get(fk.table), side: "left" },
        route: "elbow",
        line: { color: spec.palette.accent, width: 1.25, endArrow: "triangle" },
        label: { text: "1:1 optional", width: 96, height: 18, fill: "FFFFFF" },
        altText: {
          title: `${fk.refSchema}.${fk.refTable} to ${fk.table}`,
          description: fk.pairs.map((pair) =>
            `${fk.refSchema}.${fk.refTable}.${pair.refColumn} → ${fk.table}.${pair.column}`).join("; "),
        },
      });
      continue;
    }
    if (!included.has(fk.refTable)) continue;
    const oneToOne = foreignKeyIsUnique(tablesByName.get(fk.table), fk);
    children.push({
      type: "connector",
      from: { id: ids.get(fk.refTable), side: "bottom" },
      to: { id: ids.get(fk.table), side: "top" },
      route: "elbow",
      line: { color: spec.palette.accent, width: 1.25, endArrow: "triangle" },
      label: { text: oneToOne ? "1:1" : "1:N", width: 42, height: 18, fill: "FFFFFF" },
      altText: {
        title: `${fk.refTable} to ${fk.table}`,
        description: `${fk.pairs.map((pair) => `${fk.refTable}.${pair.refColumn} → ${fk.table}.${pair.column}`).join("; ")}; ON DELETE ${fk.deleteRule}`,
      },
    });
  }

  return [
    new Paragraph({ children: [new PageBreak()] }),
    paragraph(spec.title, {
      heading: HeadingLevel.HEADING_1,
      size: 28,
      bold: true,
      color: spec.palette.accent,
      after: 60,
    }),
    paragraph("Editable Word ER diagram · live public-schema metadata", {
      size: 17,
      color: COLORS.muted,
      after: 65,
    }),
    new Paragraph({
      alignment: AlignmentType.CENTER,
      spacing: { before: 0, after: 35 },
      children: [new ShapeCanvasRun({
        transformation: { width: 960, height: 500 },
        children,
        fill: COLORS.white,
        line: { color: "E1E7ED", width: 0.8 },
        fallback: true,
        altText: {
          title: `Supabase database diagram: ${spec.title}`,
          description: "Editable Word shapes and attached connectors for live Supabase tables.",
        },
      })],
    }),
    paragraph(spec.note, { size: 16, color: COLORS.muted, after: 35 }),
    paragraph("Diagram boxes and connectors are native Word drawing objects. Select a box to edit its text or move it; connectors stay attached.", {
      size: 15,
      color: COLORS.muted,
      after: 0,
    }),
  ];
}

function relationshipSection(schema) {
  const rows = [["Referenced table", "Referenced key", "Child table", "Foreign-key column(s)", "Delete rule"]];
  for (const fk of schema.foreignKeys) {
    rows.push([
      fk.refSchema && fk.refSchema !== "public" ? `${fk.refSchema}.${fk.refTable}` : fk.refTable,
      fk.pairs.map((pair) => pair.refColumn).join(", "),
      fk.table,
      fk.pairs.map((pair) => pair.column).join(", "),
      fk.deleteRule,
    ]);
  }
  return [
    new Paragraph({ children: [new PageBreak()] }),
    paragraph("Foreign-key relationship register", {
      heading: HeadingLevel.HEADING_1,
      size: 28,
      bold: true,
      after: 75,
    }),
    paragraph("These are database-enforced relationships discovered in Supabase. Application-level identifiers without a PostgreSQL foreign-key constraint are not listed here.", {
      size: 17,
      color: COLORS.muted,
      after: 120,
    }),
    dataTable(rows, [2300, 2100, 2600, 3400, 3000]),
  ];
}

function dictionarySection(schema) {
  const content = [
    new Paragraph({ children: [new PageBreak()] }),
    paragraph("Live Supabase data dictionary", {
      heading: HeadingLevel.HEADING_1,
      size: 28,
      bold: true,
      after: 60,
    }),
    paragraph("Column names, PostgreSQL types, key constraints, nullability and defaults are read from information_schema. These Word tables are fully editable.", {
      size: 17,
      color: COLORS.muted,
      after: 120,
    }),
  ];
  for (const table of schema.tables) {
    content.push(paragraph(table.name, {
      heading: HeadingLevel.HEADING_2,
      size: 21,
      bold: true,
      color: COLORS.blue,
      before: 80,
      after: 45,
      keepNext: true,
    }));
    const rows = [["Column", "PostgreSQL type", "Key / relation", "Nullable", "Default"]];
    for (const column of table.columns) {
      rows.push([
        column.name,
        column.displayType,
        column.keyFlags.join("; ") || "—",
        column.nullable ? "Yes" : "No",
        column.default || "—",
      ]);
    }
    content.push(dataTable(rows, [2900, 2400, 4600, 1350, 4150]));
  }
  return content;
}

const TABLE_INFO_AR = {
  ai_chat_messages: ["الذكاء الاصطناعي", "يحفظ رسائل المستخدم والنموذج ضمن جلسة محادثة مرتبطة بالحساب."],
  airports: ["بيانات مرجعية", "قاموس المطارات ورموزها ومدنها وبيانات البحث والموقع."],
  api_tokens: ["الهوية والأمان", "يحفظ بصمات رموز الجلسات وتواريخ انتهائها؛ لا يخزن الرمز الخام."],
  attraction_visit_counts: ["المعالم", "عداد إجمالي للزيارات لكل معلم من سجل tourist_monuments."],
  attraction_visit_dedup: ["المعالم", "يمنع تكرار احتساب الزيارة للزائر نفسه باستخدام بصمة غير مباشرة."],
  bookings: ["الحجوزات", "يسجل حجوزات الفنادق والسيارات والباقات، ويرتبط اختيارياً برحلة ومخزون شريك."],
  flight_seat_holds: ["الطيران", "يحجز المقاعد مؤقتاً؛ المفتاح المركب يجمع معرّف عرض الرحلة ورقم المقعد."],
  hotel_destinations: ["بيانات مرجعية", "فهرس وجهات الفنادق، مثل المدن والمناطق والدول، مع أسماء عربية وإحداثيات اختيارية."],
  landmark_merge_candidates: ["المعالم", "يسجل أزواج الأماكن المرشحة للمراجعة لتحديد ما إذا كانت مكررة أو منفصلة."],
  landmark_place_aliases: ["المعالم", "يربط أسماء بديلة موحّدة بلغات ومصادر مختلفة بالمعلم الأصلي."],
  landmark_places: ["المعالم", "سجل الأماكن الواردة من مزودي البيانات، مع إحداثيات وبيانات متعددة اللغات ورابط اختياري إلى السجل الموحد."],
  landmark_search_areas: ["المعالم", "ذاكرة مؤقتة لطلبات ونتائج بحث الأماكن حسب المنطقة واللغة ومدة الصلاحية."],
  legacy_attraction_partner_reviews: ["إدارة الشركاء", "يوثق قرارات الإدارة عند مراجعة بيانات الشركاء السياحية القديمة."],
  offer_catalog_metadata: ["العروض", "يحفظ بيانات وصفية إضافية لكل عرض، مثل الشارة، بعلاقة واحد إلى واحد مع offers."],
  offers: ["العروض", "يحفظ الباقات السياحية ومعلومات الوجهة والسعر والمدة والمزايا، مع ربط اختياري برحلة من مخزون الشركاء."],
  partner_listings: ["مخزون الشركاء", "يجمع عروض الفنادق والسيارات والرحلات والخدمات المقدمة من الشركاء، مع بيانات مرنة داخل JSONB."],
  partners: ["مخزون الشركاء", "يمثل شركة أو مزود خدمة وحالته ونوع الخدمة التي يقدمها."],
  password_reset_codes: ["الهوية والأمان", "يحفظ بصمة رمز الاستعادة وتاريخ الانتهاء وعدد المحاولات، ومفتاحه الأساسي البريد الإلكتروني."],
  payment_attempts: ["الدفع", "يسجل محاولات الدفع وربطها اختيارياً بحجز أو رحلة أو خدمة نقل؛ تدفق الدفع في التطبيق تجريبي وليس خصماً فعلياً."],
  schema_migrations: ["إدارة المخطط", "يسجل إصدارات تحديثات مخطط قاعدة البيانات وأسماءها وتواريخها."],
  tourist_monuments: ["المعالم", "كتالوج المعالم الذي يديره التطبيق، مع العنوان والوصف والتقييم والتصنيف والصورة."],
  transfer_schedules: ["النقل", "تفاصيل مدة خدمة النقل؛ transfer_id مفتاح أساسي وأجنبي، لذلك العلاقة مع transfers واحد إلى واحد."],
  transfers: ["النقل", "يسجل خدمة النقل المحجوزة، ومواقع الالتقاط والوصول والتوقيت والسعر والركاب."],
  travel_preferences: ["بيانات المستخدم", "تفضيلات السفر لكل مستخدم مثل الميزانية والسرعة والمدة والاهتمامات والوجهة."],
  trips: ["الرحلات", "يمثل رحلة المستخدم، ويتضمن مسار الطيران والتواريخ والناقل والدرجة والسعر وحالة الرحلة."],
  user_favorites: ["بيانات المستخدم", "يحفظ الأماكن أو العناصر المفضلة للمستخدم؛ item_id متعدد الأنواع ولا يرتبط بمفتاح أجنبي موحد."],
  user_notifications: ["التنبيهات", "يحفظ رسائل صندوق الإشعارات وحالة قراءتها ومرجعاً اختيارياً للعنصر المرتبط."],
  user_price_alerts: ["بيانات المستخدم", "يحفظ تنبيهات أسعار الرحلات حسب خط السير وتاريخ المغادرة والسعر المرجعي بالدولار."],
  user_profiles: ["بيانات المستخدم", "يحفظ بيانات الملف الإضافية، مثل رابط الصورة، ويستخدم user_id مفتاحاً أساسياً وأجنبياً."],
  user_push_tokens: ["التنبيهات", "يربط رمز الإشعار الفوري بالجهاز والمنصة وحساب المستخدم."],
  user_reviews: ["التقييمات", "يحفظ تقييم المستخدم وتعليقه؛ قيد التفرد يمنع تكرار تقييم الهدف نفسه من المستخدم ذاته."],
  user_settings: ["بيانات المستخدم", "يحفظ إعدادات اللغة والعملة والمظهر والإشعارات بصيغة JSONB لكل مستخدم."],
  users: ["الهوية والأمان", "السجل الأساسي للحساب، والبريد الفريد وكلمة المرور المشفرة والدور وربط الشريك."],
};

function arabicCell(text, header = false) {
  return new TableCell({
    shading: {
      fill: header ? "E8EEF4" : COLORS.white,
      type: ShadingType.CLEAR,
    },
    margins: { top: 65, bottom: 65, left: 90, right: 90 },
    borders: Object.fromEntries(["top", "bottom", "left", "right"].map((side) => [
      side,
      { style: BorderStyle.SINGLE, size: 3, color: COLORS.border },
    ])),
    children: [paragraph(text, {
      size: header ? 16 : 15,
      bold: header,
      color: header ? COLORS.ink : COLORS.muted,
      alignment: AlignmentType.RIGHT,
      rtl: true,
      after: 0,
    })],
  });
}

function arabicDataTable(rows, widths) {
  return new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    columnWidths: widths,
    visuallyRightToLeft: true,
    rows: rows.map((row, index) => new TableRow({
      tableHeader: index === 0,
      children: row.map((value) => arabicCell(value, index === 0)),
    })),
  });
}

function arabicDiagramPage(spec, schema, tablesByName, pageIndex) {
  const children = [];
  const included = new Set(spec.entries.map(([name]) => name));
  const ids = new Map();
  for (const [name, x, y] of spec.entries) {
    const table = tablesByName.get(name);
    if (!table) throw new Error(`Expected Supabase table is missing: ${name}`);
    const id = `ar_p${pageIndex}_${name}`;
    ids.set(name, id);
    children.push(entityShape(table, id, x, y, spec.palette));
  }
  for (const external of spec.externalEntries || []) {
    children.push(externalShape(
      `ar_p${pageIndex}_${external.id}`,
      external.label,
      external.x,
      external.y,
      spec.palette,
    ));
  }
  for (const fk of schema.foreignKeys) {
    if (!included.has(fk.table)) continue;
    if (fk.refSchema && fk.refSchema !== "public") {
      const external = (spec.externalEntries || []).find(
        (item) => item.schemaTable === `${fk.refSchema}.${fk.refTable}`,
      );
      if (!external) continue;
      children.push({
        type: "connector",
        from: { id: `ar_p${pageIndex}_${external.id}`, side: "right" },
        to: { id: ids.get(fk.table), side: "left" },
        route: "elbow",
        line: { color: spec.palette.accent, width: 1.25, endArrow: "triangle" },
        label: { text: "1:1*", width: 50, height: 18, fill: "FFFFFF" },
        altText: {
          title: `${fk.refSchema}.${fk.refTable} to ${fk.table}`,
          description: fk.pairs.map((pair) =>
            `${fk.refSchema}.${fk.refTable}.${pair.refColumn} → ${fk.table}.${pair.column}`).join("; "),
        },
      });
      continue;
    }
    if (!included.has(fk.refTable)) continue;
    const oneToOne = foreignKeyIsUnique(tablesByName.get(fk.table), fk);
    children.push({
      type: "connector",
      from: { id: ids.get(fk.refTable), side: "bottom" },
      to: { id: ids.get(fk.table), side: "top" },
      route: "elbow",
      line: { color: spec.palette.accent, width: 1.25, endArrow: "triangle" },
      label: { text: oneToOne ? "1:1" : "1:N", width: 42, height: 18, fill: "FFFFFF" },
      altText: {
        title: `${fk.refTable} to ${fk.table}`,
        description: `${fk.pairs.map((pair) => `${fk.refTable}.${pair.refColumn} → ${fk.table}.${pair.column}`).join("; ")}; ON DELETE ${fk.deleteRule}`,
      },
    });
  }
  return [
    new Paragraph({ children: [new PageBreak()] }),
    paragraph(spec.titleAr, {
      heading: HeadingLevel.HEADING_1,
      size: 27,
      bold: true,
      color: spec.palette.accent,
      alignment: AlignmentType.RIGHT,
      rtl: true,
      after: 50,
    }),
    paragraph("مخطط علاقات قابل للتحرير داخل Word؛ أسماء الجداول والأعمدة مطابقة للمخطط الفعلي في Supabase.", {
      size: 16,
      color: COLORS.muted,
      alignment: AlignmentType.RIGHT,
      rtl: true,
      after: 55,
    }),
    new Paragraph({
      alignment: AlignmentType.CENTER,
      spacing: { before: 0, after: 35 },
      children: [new ShapeCanvasRun({
        transformation: { width: 960, height: 500 },
        children,
        fill: COLORS.white,
        line: { color: "E1E7ED", width: 0.8 },
        fallback: true,
        altText: {
          title: `مخطط قاعدة بيانات Zentrip: ${spec.titleAr}`,
          description: "مربعات وموصلات Word أصلية قابلة للتحرير، مستخرجة من قيود Supabase الفعلية.",
        },
      })],
    }),
    paragraph(spec.noteAr, {
      size: 15,
      color: COLORS.muted,
      alignment: AlignmentType.RIGHT,
      rtl: true,
      after: 30,
    }),
    paragraph("في هذا المخطط: PK مفتاح أساسي، FK مفتاح أجنبي، و1:N تعني واحداً إلى متعدد. التفاصيل الكاملة لكل عمود موضحة في قاموس الجداول.", {
      size: 14,
      color: COLORS.muted,
      alignment: AlignmentType.RIGHT,
      rtl: true,
      after: 0,
    }),
  ];
}

function arabicTableIndexSection(schema) {
  const rows = [["الجدول", "المجال", "الغرض ووظيفة الجدول"]];
  for (const table of schema.tables) {
    const [domain, purpose] = TABLE_INFO_AR[table.name] || [
      "بيانات مساندة",
      "جدول تشغيلي موجود في المخطط الفعلي؛ تشرح قائمة الأعمدة بنيته.",
    ];
    rows.push([table.name, domain, purpose]);
  }
  return [
    new Paragraph({ children: [new PageBreak()] }),
    paragraph("الجداول ووظائفها داخل المنصة", {
      heading: HeadingLevel.HEADING_1,
      size: 27,
      bold: true,
      alignment: AlignmentType.RIGHT,
      rtl: true,
      after: 70,
    }),
    paragraph("يوضح الجدول الآتي دور كل جدول في تدفقات Zentrip. أسماء الجداول تبقى كما هي في PostgreSQL لتسهيل مطابقتها مع الكود والاستعلامات.", {
      size: 16,
      alignment: AlignmentType.RIGHT,
      rtl: true,
      after: 100,
    }),
    arabicDataTable(rows, [3400, 2600, 9500]),
  ];
}

function arabicFunctionsSection(schema) {
  const enabledRls = schema.rowSecurity.filter((item) => item.enabled).length;
  const disabledRls = schema.rowSecurity.filter((item) => !item.enabled);
  const forcedRls = schema.rowSecurity.filter((item) => item.forced).length;
  const disabledNames = disabledRls.map((item) => item.table).join("، ") || "لا يوجد";
  const rows = [
    ["الدالة", "وظيفتها في قاعدة البيانات", "ملاحظة الاستخدام"],
    ["zentrip_rls_user_id()", "قراءة معرّف المستخدم الذي يضعه الخادم في سياق المعاملة الحالية.", "تستخدمها سياسات RLS مع دور الخادم الآمن."],
    ["zentrip_rls_role()", "قراءة الدور الموثّق (عميل أو شريك أو مدير) من سياق المعاملة.", "لا ينبغي اشتقاق الدور من قيمة يرسلها العميل."],
    ["zentrip_rls_partner_id()", "قراءة معرّف الشريك المرتبط بطلب موثّق.", "تساعد على تقييد سجلات الشريك ببياناته."],
    ["zentrip_adjust_listing_inventory(...)", "تعديل مخزون الغرف أو المركبات أو مقاعد الرحلات ضمن شروط النوع والتوفر والصلاحية.", "وظيفة محمية من نوع SECURITY DEFINER."],
    ["zentrip_lock_flight_listing(...)", "قفل سجل عرض الرحلة أثناء حجز المقاعد لتقليل تعارض الحجوزات المتزامنة.", "تعمل ضمن معاملة حجز."],
    ["zentrip_register_user_push_token(...)", "تسجيل رمز جهاز الإشعارات للمستخدم والمنصة مع تحديث آخر ظهور.", "تتحقق من الدور ونوع المنصة."],
    ["set_updated_at()", "تحديث updated_at تلقائياً قبل تعديل سجل.", "تُستخدم بواسطة مشغلات BEFORE UPDATE في عدة جداول."],
    ["current_app_user_id()", "تحويل auth.uid() إلى سجل users عبر users.auth_user_id.", "موجودة في Supabase؛ مسار API في Java يعتمد حالياً users/api_tokens ولا يستخدمها لتوثيق الطلبات."],
  ];
  const content = [
    new Paragraph({ children: [new PageBreak()] }),
    paragraph("وظائف قاعدة البيانات والأمان", {
      heading: HeadingLevel.HEADING_1,
      size: 27,
      bold: true,
      alignment: AlignmentType.RIGHT,
      rtl: true,
      after: 70,
    }),
    paragraph("تمت مراجعة أسماء الدوال العامة في Supabase ومقارنتها بالترحيلات والكود. لا يتضمن الجدول أدناه دوال امتداد pg_trgm العامة لأنها أدوات بحث PostgreSQL وليست منطق أعمال خاصاً بالمنصة.", {
      size: 16,
      alignment: AlignmentType.RIGHT,
      rtl: true,
      after: 100,
    }),
    arabicDataTable(rows, [3600, 6500, 5400]),
    paragraph("سياسات الصفوف (RLS)", {
      heading: HeadingLevel.HEADING_2,
      size: 22,
      bold: true,
      alignment: AlignmentType.RIGHT,
      rtl: true,
      before: 160,
      after: 55,
    }),
    paragraph(`في قراءة المخطط الحالية، RLS مفعّل على ${enabledRls} من أصل ${schema.rowSecurity.length} جدولاً عاماً. الجداول التي لا تفعّله: ${disabledNames}. عدد الجداول التي تستخدم FORCE ROW LEVEL SECURITY هو ${forcedRls}. يضع RlsContextFilter الدور ومعرّفات المستخدم والشريك بعد التحقق من رمز API، داخل معاملة واحدة وباستخدام SET LOCAL ROLE حتى لا ينتقل السياق بين اتصالات مجمّع Supabase.`, {
      size: 16,
      alignment: AlignmentType.RIGHT,
      rtl: true,
      after: 70,
    }),
    paragraph("تستخدم واجهة Java رموزاً مخزنة كبصمات في api_tokens، ولا تعتمد auth.uid() بوصفه مصدر الهوية الأساسي. يحتوي المخطط الفعلي كذلك على users.auth_user_id اختياري ومفتاح أجنبي إلى auth.users.id؛ وهو ربط إضافي موجود في Supabase، وليس بديلاً عن مسار التوثيق الحالي.", {
      size: 16,
      alignment: AlignmentType.RIGHT,
      rtl: true,
      after: 70,
    }),
    paragraph("يخزن جدول payment_attempts محاولات الدفع لأغراض تدفق الحجز، لكن الدفع في التطبيق محاكاة ولا يمثل خصماً حقيقياً لمزود دفع خارجي.", {
      size: 16,
      alignment: AlignmentType.RIGHT,
      rtl: true,
      after: 0,
    }),
  ];
  const customRoutines = new Set([
    "zentrip_rls_user_id",
    "zentrip_rls_role",
    "zentrip_rls_partner_id",
    "zentrip_adjust_listing_inventory",
    "zentrip_lock_flight_listing",
    "zentrip_register_user_push_token",
    "set_updated_at",
    "current_app_user_id",
  ]);
  const liveRoutineNames = new Set(
    schema.routines ? schema.routines.map((routine) => routine.name) : [],
  );
  for (const name of customRoutines) {
    if (!liveRoutineNames.has(name)) {
      throw new Error(`Expected live Supabase function is missing: ${name}`);
    }
  }
  return content;
}

function arabicRelationshipSection(schema) {
  const deleteLabels = {
    CASCADE: "حذف تابع (CASCADE)",
    "SET NULL": "إفراغ المرجع (SET NULL)",
    RESTRICT: "منع الحذف عند وجود سجل تابع (RESTRICT)",
    "NO ACTION": "الإجراء الافتراضي (NO ACTION)",
    "SET DEFAULT": "استخدام القيمة الافتراضية (SET DEFAULT)",
  };
  const rows = [["الجدول المرجعي", "المفتاح المرجعي", "الجدول التابع", "عمود المفتاح الأجنبي", "سلوك الحذف"]];
  for (const fk of schema.foreignKeys) {
    rows.push([
      fk.refSchema && fk.refSchema !== "public" ? `${fk.refSchema}.${fk.refTable}` : fk.refTable,
      fk.pairs.map((pair) => pair.refColumn).join(", "),
      fk.table,
      fk.pairs.map((pair) => pair.column).join(", "),
      deleteLabels[fk.deleteRule] || fk.deleteRule,
    ]);
  }
  return [
    new Paragraph({ children: [new PageBreak()] }),
    paragraph("سجل العلاقات المفروضة في PostgreSQL", {
      heading: HeadingLevel.HEADING_1,
      size: 27,
      bold: true,
      alignment: AlignmentType.RIGHT,
      rtl: true,
      after: 60,
    }),
    paragraph("تسرد هذه الصفحة جميع المفاتيح الأجنبية التي قرأها التقرير من Supabase. ويشمل ذلك المرجع الخارجي auth.users؛ أما الروابط التي يفرضها التطبيق دون FK، مثل item_id متعدد الأنواع، فلا تظهر ضمن هذا السجل.", {
      size: 16,
      alignment: AlignmentType.RIGHT,
      rtl: true,
      after: 100,
    }),
    arabicDataTable(rows, [2600, 1900, 2700, 3000, 5300]),
  ];
}

function arabicDictionarySection(schema) {
  const content = [
    new Paragraph({ children: [new PageBreak()] }),
    paragraph("قاموس أعمدة قاعدة البيانات", {
      heading: HeadingLevel.HEADING_1,
      size: 27,
      bold: true,
      alignment: AlignmentType.RIGHT,
      rtl: true,
      after: 55,
    }),
    paragraph("يستند هذا القاموس إلى الأعمدة والأنواع والقيود والقيم الافتراضية التي قرأها التقرير مباشرة من المخطط العام في Supabase. الجداول قابلة للتحرير داخل Word، وأسماء الأعمدة محفوظة كما هي في قاعدة البيانات.", {
      size: 16,
      alignment: AlignmentType.RIGHT,
      rtl: true,
      after: 100,
    }),
  ];
  for (const table of schema.tables) {
    const [domain, purpose] = TABLE_INFO_AR[table.name] || [
      "بيانات مساندة",
      "جدول تشغيلي موجود في المخطط الفعلي.",
    ];
    content.push(paragraph(table.name, {
      heading: HeadingLevel.HEADING_2,
      size: 20,
      bold: true,
      color: COLORS.blue,
      before: 100,
      after: 30,
      keepNext: true,
    }));
    content.push(paragraph(`${domain}: ${purpose}`, {
      size: 14,
      color: COLORS.muted,
      alignment: AlignmentType.RIGHT,
      rtl: true,
      after: 35,
      keepNext: true,
    }));
    const rows = [["العمود", "نوع PostgreSQL", "المفتاح أو العلاقة", "يسمح بـ NULL", "القيمة الافتراضية"]];
    for (const column of table.columns) {
      rows.push([
        column.name,
        column.displayType,
        column.keyFlags.join("; ") || "—",
        column.nullable ? "نعم" : "لا",
        column.default || "—",
      ]);
    }
    content.push(arabicDataTable(rows, [2500, 2200, 4200, 1500, 4500]));
  }
  return content;
}

function buildArabicDocument(schema) {
  const tablesByName = new Map(schema.tables.map((table) => [table.name, table]));
  const totalColumns = schema.tables.reduce((sum, table) => sum + table.columns.length, 0);
  const diagramTables = new Set(PAGES.flatMap((page) => page.entries.map(([name]) => name)));
  const missingFromDiagrams = schema.tables
    .map((table) => table.name)
    .filter((name) => !diagramTables.has(name));
  if (missingFromDiagrams.length) {
    throw new Error(`Tables missing from diagrams: ${missingFromDiagrams.join(", ")}`);
  }
  const missingRelationships = schema.foreignKeys.filter((fk) => !PAGES.some((page) => {
    const childIncluded = page.entries.some(([name]) => name === fk.table);
    if (!childIncluded) return false;
    if (fk.refSchema && fk.refSchema !== "public") {
      return (page.externalEntries || []).some(
        (item) => item.schemaTable === `${fk.refSchema}.${fk.refTable}`,
      );
    }
    return page.entries.some(([name]) => name === fk.refTable);
  }));
  if (missingRelationships.length) {
    throw new Error(`Foreign keys missing from diagrams: ${missingRelationships.map((fk) => fk.name).join(", ")}`);
  }
  const date = new Intl.DateTimeFormat("ar", {
    dateStyle: "long",
    timeZone: "UTC",
  }).format(new Date());
  const content = [
    paragraph("قاعدة بيانات Zentrip على Supabase", {
      heading: HeadingLevel.TITLE,
      alignment: AlignmentType.CENTER,
      size: 32,
      bold: true,
      after: 50,
    }),
    paragraph("شرح أكاديمي للجداول والعلاقات ووظائف قاعدة البيانات", {
      alignment: AlignmentType.CENTER,
      size: 20,
      color: COLORS.muted,
      after: 130,
    }),
    arabicDataTable([
      ["عنصر التحقق", "نتيجة قراءة Supabase"],
      ["المخطط", `${schema.database} / ${schema.schema}`],
      ["إصدار PostgreSQL", schema.serverVersion],
      ["الجداول العامة", String(schema.tables.length)],
      ["الأعمدة", String(totalColumns)],
      ["المفاتيح الأجنبية", String(schema.foreignKeys.length)],
      ["تاريخ القراءة", date],
      ["نطاق القراءة", "بيانات وصفية للمخطط فقط؛ لم تُقرأ سجلات العملاء أو الحجوزات"],
    ], [4800, 10600]),
    paragraph("مقدمة", {
      heading: HeadingLevel.HEADING_1,
      size: 25,
      bold: true,
      alignment: AlignmentType.RIGHT,
      rtl: true,
      before: 150,
      after: 55,
    }),
    paragraph("تستضيف منصة Zentrip بياناتها التشغيلية في قاعدة PostgreSQL ضمن مشروع Supabase. ويعتمد تطبيق الهاتف المبني بـ Flutter على واجهات REST في خدمة Java وSpring Boot للوصول إلى البيانات؛ لذلك تمر عمليات التسجيل والبحث والحجز والإدارة عبر الخادم قبل حفظها أو قراءتها من قاعدة البيانات.", {
      size: 17,
      alignment: AlignmentType.RIGHT,
      rtl: true,
      after: 65,
    }),
    paragraph("يصف هذا المستند المخطط الحي في مساحة public كما ظهر أثناء القراءة، وليس ملف schema.sql وحده. تتضمن اللقطة 33 جدولاً و321 عموداً و41 مفتاحاً أجنبياً. ومن الفروق المهمة أن users.auth_user_id موجود في Supabase ويرتبط بـ auth.users.id، مع أن مخطط المشروع المحلي لا يعكس كل الفروق الحية؛ أما توثيق API الحالي فيعتمد أساساً users وapi_tokens.", {
      size: 17,
      alignment: AlignmentType.RIGHT,
      rtl: true,
      after: 65,
    }),
    paragraph("يستخدم PostgreSQL الأنواع العلائقية والقيود لضبط الهوية والعلاقات، كما يستخدم JSONB لبعض التفاصيل المرنة مثل مواصفات عروض الشركاء وإعدادات المستخدم. وتساعد المفاتيح والفهارس على التحقق من الاتساق وتسريع الاستعلامات، بينما تضبط سياسات RLS نطاق الصفوف التي يسمح لكل دور بقراءتها أو تعديلها.", {
      size: 17,
      alignment: AlignmentType.RIGHT,
      rtl: true,
      after: 0,
    }),
    ...arabicTableIndexSection(schema),
  ];
  for (let index = 0; index < PAGES.length; index++) {
    content.push(...arabicDiagramPage(PAGES[index], schema, tablesByName, index + 1));
  }
  content.push(...arabicFunctionsSection(schema));
  content.push(...arabicRelationshipSection(schema));
  content.push(...arabicDictionarySection(schema));
  return new Document({
    creator: "Zentrip",
    title: "قاعدة بيانات Zentrip على Supabase",
    subject: "شرح عربي للمخطط الحي والعلاقات وقاموس البيانات",
    description: "مستند عربي منشأ من قراءة وصفية للبيانات الوصفية في مخطط Supabase العام.",
    sections: [{
      properties: {
        page: {
          size: { width: 16838, height: 11906, orientation: PageOrientation.LANDSCAPE },
          margin: { top: 650, right: 720, bottom: 650, left: 720 },
        },
      },
      children: content,
    }],
  });
}

function buildDocument(schema) {
  const tablesByName = new Map(schema.tables.map((table) => [table.name, table]));
  const totalColumns = schema.tables.reduce((sum, table) => sum + table.columns.length, 0);
  const systemTable = tablesByName.get("flyway_schema_history");
  const snapshotDate = new Intl.DateTimeFormat("en-GB", {
    dateStyle: "long",
    timeZone: "UTC",
  }).format(new Date());
  const front = [
    paragraph("ZenTrip — Supabase Database Diagram", {
      heading: HeadingLevel.TITLE,
      alignment: AlignmentType.CENTER,
      size: 34,
      bold: true,
      after: 70,
    }),
    paragraph("Editable entity–relationship diagrams and live schema reference", {
      alignment: AlignmentType.CENTER,
      size: 20,
      color: COLORS.muted,
      after: 170,
    }),
    dataTable([
      ["Snapshot item", "Live Supabase result"],
      ["Database / schema", `${schema.database} / ${schema.schema}`],
      ["PostgreSQL version", schema.serverVersion],
      ["Public base tables", String(schema.tables.length)],
      ["Columns", String(totalColumns)],
      ["Declared foreign keys", String(schema.foreignKeys.length)],
      ["Read scope", "Catalog metadata only; no customer or booking rows read"],
      ["System table", systemTable ? "flyway_schema_history — migration history, no application foreign keys" : "Not present"],
      ["Snapshot date", snapshotDate],
    ], [4600, 10800]),
    paragraph("How to read the diagrams", {
      heading: HeadingLevel.HEADING_1,
      size: 25,
      bold: true,
      before: 170,
      after: 70,
    }),
    paragraph("Each entity is a native editable Word shape. PK marks the primary key; FK lines show the child-column reference; UQ denotes a unique constraint. Connectors point from a referenced table to the table that stores the foreign key. 1:1 appears when the child foreign-key column is unique; otherwise 1:N.", {
      size: 18,
      after: 100,
    }),
    paragraph("Only relationships enforced by PostgreSQL foreign keys are drawn. Some app-level links (such as user_reviews.item_id and password_reset_codes.email) are documented as notes, not presented as database-enforced links.", {
      size: 18,
      after: 0,
    }),
  ];

  const content = [...front];
  for (let i = 0; i < PAGES.length; i++) {
    content.push(...diagramPage(PAGES[i], schema, tablesByName, i + 1));
  }
  content.push(...relationshipSection(schema));
  content.push(...dictionarySection(schema));

  return new Document({
    creator: "Zentrip",
    title: "Zentrip Supabase Database Diagram",
    subject: "Live public-schema ERD and editable data dictionary",
    description: "Generated from read-only PostgreSQL catalog metadata in Supabase.",
    sections: [{
      properties: {
        page: {
          size: { width: 16838, height: 11906, orientation: PageOrientation.LANDSCAPE },
          margin: { top: 650, right: 720, bottom: 650, left: 720 },
        },
      },
      children: content,
    }],
  });
}

async function main() {
  const schema = prepareSchema(readLiveSchema());
  fs.mkdirSync(path.dirname(OUTPUT), { recursive: true });
  const buffer = await Packer.toBuffer(buildDocument(schema));
  fs.writeFileSync(OUTPUT, buffer);
  const arabicBuffer = await Packer.toBuffer(buildArabicDocument(schema));
  fs.writeFileSync(ARABIC_OUTPUT, arabicBuffer);
  const columns = schema.tables.reduce((sum, table) => sum + table.columns.length, 0);
  console.log(`Created ${path.relative(ROOT, OUTPUT)} from Supabase public schema: `
    + `${schema.tables.length} tables, ${columns} columns, ${schema.foreignKeys.length} foreign keys.`);
  console.log(`Created ${path.relative(ROOT, ARABIC_OUTPUT)} with Arabic explanations and editable diagrams.`);
}

main().catch((error) => {
  // Do not print database URLs, usernames, passwords, or raw connection errors.
  console.error(`Schema diagram generation failed: ${error.message}`);
  process.exitCode = 1;
});
