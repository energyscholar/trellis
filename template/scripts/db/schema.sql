-- Longmem DB schema — SQLite acceleration layer
-- Flat files (.longmem/memory/*.md) remain source of truth.
-- This DB is a read cache rebuilt from those files via ingest + rebuild.

PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

-- ============================================================================
-- Core memory tables
-- ============================================================================

CREATE TABLE corrections(
    id INTEGER PRIMARY KEY,
    number INTEGER UNIQUE NOT NULL,
    title TEXT NOT NULL,
    context TEXT,
    type TEXT CHECK(type IN ('domain', 'epistemic', 'architecture', 'identity')),
    depth TEXT CHECK(depth IN ('routing-change', 'nuance', 'addition')),
    cluster TEXT CHECK(cluster IN ('orientation', 'epistemic', 'technical', 'identity')),
    notice TEXT,
    source TEXT,
    domain TEXT,
    established TEXT,
    last_violated TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE correction_connections(
    correction_id INTEGER NOT NULL REFERENCES corrections(id),
    connected_id INTEGER NOT NULL REFERENCES corrections(id),
    relationship TEXT,
    PRIMARY KEY (correction_id, connected_id)
);

CREATE TABLE feedback(
    id INTEGER PRIMARY KEY,
    slug TEXT UNIQUE NOT NULL,
    rule TEXT,
    why TEXT,
    how_to_apply TEXT,
    content TEXT,
    established TEXT,
    last_triggered TEXT,
    source TEXT,
    domain TEXT NOT NULL DEFAULT 'general',
    opsec_level TEXT CHECK(opsec_level IN ('public', 'trusted', 'restricted', 'compartmented')),
    compaction_tag TEXT,
    source_file TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE projects(
    id INTEGER PRIMARY KEY,
    slug TEXT UNIQUE NOT NULL,
    name TEXT,
    status TEXT DEFAULT 'active'
        CHECK(status IN ('active', 'stale', 'archived', 'blocked', 'complete')),
    description TEXT,
    why TEXT,
    how_to_apply TEXT,
    content TEXT,
    domain TEXT NOT NULL DEFAULT 'general',
    opsec_level TEXT CHECK(opsec_level IN ('public', 'trusted', 'restricted', 'compartmented')),
    compaction_tag TEXT,
    source_file TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE "references"(
    id INTEGER PRIMARY KEY,
    slug TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    path_or_url TEXT,
    description TEXT,
    opsec_level TEXT CHECK(opsec_level IN ('public', 'trusted', 'restricted', 'compartmented')),
    source_file TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE user_profile(
    id INTEGER PRIMARY KEY,
    slug TEXT UNIQUE NOT NULL,
    attribute TEXT NOT NULL,
    value TEXT,
    context TEXT,
    source_file TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE people(
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    tier INTEGER,
    tier_notes TEXT,
    role TEXT,
    relationship TEXT,
    description TEXT,
    email TEXT,
    handles TEXT,
    approach_notes TEXT,
    opsec_level TEXT CHECK(opsec_level IN ('public', 'trusted', 'restricted', 'compartmented')),
    status TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE person_projects(
    person_id INTEGER NOT NULL REFERENCES people(id),
    project_slug TEXT NOT NULL,
    PRIMARY KEY (person_id, project_slug)
);

-- ============================================================================
-- Session tracking
-- ============================================================================

CREATE TABLE sessions(
    id INTEGER PRIMARY KEY,
    number INTEGER UNIQUE NOT NULL,
    date TEXT,
    significance TEXT NOT NULL DEFAULT 'PARADIGM'
        CHECK(significance IN ('PARADIGM', 'ROUTINE')),
    register TEXT,
    summary TEXT,
    reconstruction_priority INTEGER,
    handoff TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE session_themes(
    session_id INTEGER NOT NULL REFERENCES sessions(id),
    theme TEXT NOT NULL,
    PRIMARY KEY (session_id, theme)
);

CREATE TABLE session_events(
    id INTEGER PRIMARY KEY,
    session_id INTEGER NOT NULL REFERENCES sessions(id),
    axis TEXT NOT NULL CHECK(axis IN ('memory', 'structure', 'ethics')),
    event TEXT NOT NULL,
    source TEXT NOT NULL DEFAULT 'human'
        CHECK(source IN ('human', 'environment', 'system')),
    set_point TEXT,
    set_point_provenance TEXT
        CHECK(set_point_provenance IS NULL OR set_point_provenance IN ('human', 'consequence')),
    created_at TEXT DEFAULT (datetime('now'))
);

-- ============================================================================
-- Knowledge tracking
-- ============================================================================

CREATE TABLE decisions(
    id INTEGER PRIMARY KEY,
    topic TEXT NOT NULL,
    decision TEXT,
    rationale TEXT,
    date TEXT,
    status TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE breakthroughs(
    id INTEGER PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'active'
        CHECK(status IN ('active', 'killed')),
    date TEXT,
    killed_date TEXT,
    killed_reason TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

-- ============================================================================
-- Task tracking
-- ============================================================================

CREATE TABLE ptl_items(
    id INTEGER PRIMARY KEY,
    stable_id TEXT UNIQUE NOT NULL,
    title TEXT NOT NULL,
    tier INTEGER NOT NULL CHECK(tier IN (1, 2, 3, 4, 5)),
    status TEXT NOT NULL CHECK(status IN (
        'READY', 'ACTIVE', 'IN_PROGRESS', 'BLOCKED', 'REVIEW',
        'NEEDS_PLAN', 'TODO', 'DONE', 'DROPPED', 'SHELF',
        'WAITING', 'ARCHIVED', 'STALE'
    )),
    owner TEXT,
    created TEXT,
    last_touched TEXT,
    decay_exempt INTEGER DEFAULT 0,
    description TEXT,
    detail_file TEXT,
    blocked_by TEXT,
    source TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE pending_items(
    id INTEGER PRIMARY KEY,
    description TEXT NOT NULL,
    status TEXT,
    tier TEXT CHECK(tier IN ('NOW', 'SOON', 'LATER')),
    created TEXT,
    last_touched TEXT,
    category TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

-- ============================================================================
-- Entity graph
-- ============================================================================

CREATE TABLE associations(
    id INTEGER PRIMARY KEY,
    source_type TEXT NOT NULL,
    source_id INTEGER NOT NULL,
    target_type TEXT NOT NULL,
    target_id INTEGER NOT NULL,
    relationship TEXT NOT NULL CHECK(relationship IN (
        'relates_to', 'contradicts', 'supersedes', 'exemplifies', 'derives_from'
    )),
    basis TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

-- ============================================================================
-- Health monitoring
-- ============================================================================

CREATE TABLE health_snapshots(
    id INTEGER PRIMARY KEY,
    session_number INTEGER,
    date TEXT,
    pressure REAL,
    freshness REAL,
    coverage REAL,
    drift REAL,
    notes TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

-- ============================================================================
-- Confidence decay overlay
-- ============================================================================
-- Metadata pattern: keyed by (source_table, source_id), bolted onto any table.
-- Branchless exponential decay via generated column.
-- Pinned items: decay_rate=0 so exp(0)=1.0 naturally.

CREATE TABLE memory_confidence(
    id INTEGER PRIMARY KEY,
    source_table TEXT NOT NULL,
    source_id INTEGER NOT NULL,
    base_confidence REAL NOT NULL DEFAULT 1.0,
    half_life_days INTEGER CHECK(half_life_days IS NULL OR half_life_days > 0),
    pinned INTEGER NOT NULL DEFAULT 0,
    decay_rate REAL GENERATED ALWAYS AS (
        CASE WHEN half_life_days IS NULL THEN 0.0
             ELSE ln(2) / half_life_days
        END
    ) STORED,
    last_accessed TEXT,
    last_reinforced TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(source_table, source_id)
);

CREATE TABLE confidence_config(
    source_table TEXT PRIMARY KEY,
    default_half_life_days INTEGER CHECK(default_half_life_days IS NULL OR default_half_life_days > 0),
    default_pinned INTEGER NOT NULL DEFAULT 0,
    description TEXT
);

-- ============================================================================
-- Evidence / provenance (append-only audit trail)
-- ============================================================================

CREATE TABLE memory_evidence(
    id INTEGER PRIMARY KEY,
    source_table TEXT NOT NULL,
    source_id INTEGER NOT NULL,
    kind TEXT NOT NULL CHECK(kind IN (
        'established', 'violated', 'referenced', 'observed', 'corrected'
    )),
    evidence_text TEXT,
    session_number INTEGER,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ============================================================================
-- Pipeline tracking
-- ============================================================================

CREATE TABLE ingest_log(
    id INTEGER PRIMARY KEY,
    source_file TEXT NOT NULL,
    table_name TEXT NOT NULL,
    action TEXT NOT NULL,
    timestamp TEXT DEFAULT (datetime('now'))
);

-- ============================================================================
-- Triggers: auto-update timestamps
-- ============================================================================

CREATE TRIGGER corrections_updated AFTER UPDATE ON corrections
BEGIN UPDATE corrections SET updated_at = datetime('now') WHERE id = NEW.id; END;

CREATE TRIGGER feedback_updated AFTER UPDATE ON feedback
BEGIN UPDATE feedback SET updated_at = datetime('now') WHERE id = NEW.id; END;

CREATE TRIGGER projects_updated AFTER UPDATE ON projects
BEGIN UPDATE projects SET updated_at = datetime('now') WHERE id = NEW.id; END;

CREATE TRIGGER references_updated AFTER UPDATE ON "references"
BEGIN UPDATE "references" SET updated_at = datetime('now') WHERE id = NEW.id; END;

CREATE TRIGGER user_profile_updated AFTER UPDATE ON user_profile
BEGIN UPDATE user_profile SET updated_at = datetime('now') WHERE id = NEW.id; END;

CREATE TRIGGER people_updated AFTER UPDATE ON people
BEGIN UPDATE people SET updated_at = datetime('now') WHERE id = NEW.id; END;

CREATE TRIGGER sessions_updated AFTER UPDATE ON sessions
BEGIN UPDATE sessions SET updated_at = datetime('now') WHERE id = NEW.id; END;

CREATE TRIGGER decisions_updated AFTER UPDATE ON decisions
BEGIN UPDATE decisions SET updated_at = datetime('now') WHERE id = NEW.id; END;

CREATE TRIGGER breakthroughs_updated AFTER UPDATE ON breakthroughs
BEGIN UPDATE breakthroughs SET updated_at = datetime('now') WHERE id = NEW.id; END;

CREATE TRIGGER ptl_items_updated AFTER UPDATE ON ptl_items
BEGIN UPDATE ptl_items SET updated_at = datetime('now') WHERE id = NEW.id; END;

CREATE TRIGGER pending_items_updated AFTER UPDATE ON pending_items
BEGIN UPDATE pending_items SET updated_at = datetime('now') WHERE id = NEW.id; END;

-- ============================================================================
-- Triggers: guardrails
-- ============================================================================

CREATE TRIGGER corrections_count_warn AFTER INSERT ON corrections
WHEN (SELECT COUNT(*) FROM corrections) > 25
BEGIN
    INSERT OR IGNORE INTO pending_items(description, status, tier, category)
    VALUES ('Corrections count high: ' || (SELECT COUNT(*) FROM corrections) ||
            ' rows — consider compacting', 'open', 'LATER', 'memory');
END;

CREATE TRIGGER feedback_compaction_preserve BEFORE UPDATE ON feedback
WHEN OLD.compaction_tag = 'NEVER COMPACT' AND NEW.compaction_tag != 'NEVER COMPACT'
BEGIN
    SELECT RAISE(ABORT, 'Cannot remove NEVER COMPACT tag');
END;

-- ============================================================================
-- FTS5 full-text search
-- ============================================================================

CREATE VIRTUAL TABLE memory_fts USING fts5(
    source_table,
    source_id UNINDEXED,
    title,
    content,
    tokenize='porter unicode61'
);

-- ============================================================================
-- Default confidence config
-- ============================================================================

INSERT INTO confidence_config VALUES ('user_profile', 365, 0, 'User facts — slow decay');
INSERT INTO confidence_config VALUES ('feedback', 90, 0, 'Behavioral rules — moderate decay');
INSERT INTO confidence_config VALUES ('projects', 60, 0, 'Project state — fast decay');
INSERT INTO confidence_config VALUES ('references', 180, 0, 'External resources — moderate decay');
INSERT INTO confidence_config VALUES ('corrections', NULL, 1, 'Corrections — pinned, no decay');
INSERT INTO confidence_config VALUES ('decisions', 90, 0, 'Decision context — moderate decay');
INSERT INTO confidence_config VALUES ('breakthroughs', 180, 0, 'Analytical advances persist');
INSERT INTO confidence_config VALUES ('people', 365, 0, 'Relationships are durable');
INSERT INTO confidence_config VALUES ('sessions', 30, 0, 'Ephemeral by nature');
