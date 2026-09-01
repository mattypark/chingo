-- ChinGo core schema.
--
-- Two rules shape every table here:
--
--   1. Nobody's precise location is ever stored where another user could reach it.
--      Live presence is a coarse cell and nothing else. The only precise coordinates in
--      the database belong to places that already happened, and they are readable only by
--      the person they happened to.
--   2. A relationship is one row, not two. Bonds are symmetric by construction, so it is
--      not possible for the database to represent "I am your best friend but you are not
--      mine".

create extension if not exists postgis;
create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- People
-- ---------------------------------------------------------------------------

create table profiles (
    id              uuid primary key references auth.users(id) on delete cascade,
    handle          text not null unique
                    check (handle ~ '^[a-z0-9_]{2,20}$'),
    display_name    text,
    -- Self-chosen personality, not stats. Three is the cap: a fourth turns a person into
    -- a resume.
    traits          text[] not null default '{}'
                    check (array_length(traits, 1) is null or array_length(traits, 1) <= 3),
    avatar_path     text,
    xp              integer not null default 0 check (xp >= 0),

    -- Age gate. The FTC banned NGL from serving under-18s and Sendit was sued over
    -- under-13 data; a location social app that is casual about this is a target, not an
    -- edge case. Stored as a boolean assertion rather than a birthdate: we need the answer,
    -- not the data.
    is_16_plus      boolean not null default false,

    -- Discovery is opt-in per session and defaults off. Being findable is something you
    -- switch on when you go out.
    discoverable    boolean not null default false,

    created_at      timestamptz not null default now()
);

-- The short code another phone scans to add you. Rotatable, so a code that leaks into a
-- screenshot can be killed without changing the handle.
create table friend_codes (
    code        text primary key check (code ~ '^[A-Z0-9]{8}$'),
    owner       uuid not null references profiles(id) on delete cascade,
    created_at  timestamptz not null default now(),
    expires_at  timestamptz not null default now() + interval '7 days'
);
create index friend_codes_owner_idx on friend_codes (owner);

-- ---------------------------------------------------------------------------
-- Bonds — one row per relationship, symmetric by construction
-- ---------------------------------------------------------------------------

create table bonds (
    -- lo/hi rather than a/b: the check constraint plus the primary key make a duplicate
    -- reversed row impossible, which is what makes the tier symmetric in the database
    -- rather than merely symmetric by convention in the client.
    lo              uuid not null references profiles(id) on delete cascade,
    hi              uuid not null references profiles(id) on delete cascade,
    meetups         integer not null default 0 check (meetups >= 0),
    distinct_places integer not null default 0 check (distinct_places >= 0),
    first_met       timestamptz not null default now(),
    last_met        timestamptz not null default now(),
    mutual_top_five boolean not null default false,
    primary key (lo, hi),
    check (lo < hi)
);
create index bonds_hi_idx on bonds (hi);

-- Always address a bond through this, never by writing lo/hi by hand at a call site.
create or replace function bond_key(a uuid, b uuid)
returns uuid[]
language sql immutable
as $$ select case when a < b then array[a, b] else array[b, a] end $$;

-- ---------------------------------------------------------------------------
-- Catches
-- ---------------------------------------------------------------------------

create type catch_kind as enum ('snap', 'tag');

create table catches (
    id            uuid primary key default gen_random_uuid(),
    initiator     uuid not null references profiles(id) on delete cascade,
    receiver      uuid not null references profiles(id) on delete cascade,
    kind          catch_kind not null,
    -- A catch is real only once the other person taps accept. Nobody is ever collected.
    accepted_at   timestamptz,
    happened_at   timestamptz not null default now(),
    -- Coarse cell, never a point. Even for a catch both people consented to, storing the
    -- exact coordinate would build the location history this product refuses to have.
    cell          text not null,
    place_label   text,
    photo_path    text,
    check (initiator <> receiver)
);
create index catches_initiator_idx on catches (initiator, happened_at desc);
create index catches_receiver_idx on catches (receiver, happened_at desc);

-- The card text one friend writes for another. Deliberately its own table: your move is
-- authored by someone else, and they keep the right to it.
create table card_moves (
    subject     uuid not null references profiles(id) on delete cascade,
    author      uuid not null references profiles(id) on delete cascade,
    text        text not null check (char_length(text) between 1 and 120),
    written_at  timestamptz not null default now(),
    primary key (subject, author)
);

-- ---------------------------------------------------------------------------
-- Memories — the half of the app that is yours alone
-- ---------------------------------------------------------------------------

create table memories (
    id              uuid primary key default gen_random_uuid(),
    owner           uuid not null references profiles(id) on delete cascade,
    friend          uuid references profiles(id) on delete set null,
    -- The photo itself never leaves the device. This is the PhotoKit local identifier, so
    -- the row is worthless to anyone who is not holding the phone that took it.
    local_asset_id  text,
    -- A memory is the one place a precise point is stored, because walking past it is the
    -- entire feature. It is readable by exactly one person: the owner.
    at              geography(point, 4326) not null,
    place_label     text,
    happened_on     date not null,
    surfaced_at     timestamptz,
    created_at      timestamptz not null default now()
);
create index memories_owner_idx on memories (owner);
create index memories_at_idx on memories using gist (at);

-- ---------------------------------------------------------------------------
-- Presence — coarse, expiring, and never a point
-- ---------------------------------------------------------------------------

create table presence (
    user_id     uuid primary key references profiles(id) on delete cascade,
    cell        text not null,
    -- Presence expires rather than being deleted on sign-out, so a killed app cannot
    -- leave someone visible forever.
    expires_at  timestamptz not null default now() + interval '20 minutes'
);
create index presence_cell_idx on presence (cell, expires_at);

-- Occupancy of a cell, for the k-anonymity gate. A security-definer function so the count
-- can be known without any row in `presence` ever being selectable.
create or replace function cell_occupancy(target_cell text)
returns integer
language sql stable security definer set search_path = public
as $$
    select count(*)::integer from presence
    where cell = target_cell and expires_at > now()
$$;

-- ---------------------------------------------------------------------------
-- Safety
-- ---------------------------------------------------------------------------

create table blocks (
    blocker     uuid not null references profiles(id) on delete cascade,
    blocked     uuid not null references profiles(id) on delete cascade,
    created_at  timestamptz not null default now(),
    primary key (blocker, blocked)
);

create table reports (
    id          uuid primary key default gen_random_uuid(),
    reporter    uuid not null references profiles(id) on delete cascade,
    subject     uuid not null references profiles(id) on delete cascade,
    reason      text not null,
    created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Money plumbing. Tables only in v1 -- no UI, no prices, nothing user-facing.
-- ---------------------------------------------------------------------------

create table sponsored_zones (
    id            uuid primary key default gen_random_uuid(),
    sponsor       text not null,
    area          geography(polygon, 4326) not null,
    starts_at     timestamptz not null,
    ends_at       timestamptz not null,
    card_style    text,
    -- Niantic's proven unit is cost-per-visit at under $0.50 per daily unique. Counting
    -- verified visits from day one means the number exists before a sponsor is ever asked
    -- for money.
    visit_budget  integer not null default 0,
    check (ends_at > starts_at)
);
create index sponsored_zones_area_idx on sponsored_zones using gist (area);

create table zone_visits (
    zone_id   uuid not null references sponsored_zones(id) on delete cascade,
    user_id   uuid not null references profiles(id) on delete cascade,
    visited_on date not null default current_date,
    primary key (zone_id, user_id, visited_on)
);

-- Append-only. Reversals are new rows, never updates, so payouts or rewards can switch on
-- later without a migration and without a rewritable balance.
create table ledger (
    id          bigserial primary key,
    user_id     uuid not null references profiles(id) on delete cascade,
    delta       integer not null,
    reason      text not null,
    created_at  timestamptz not null default now()
);
create index ledger_user_idx on ledger (user_id, created_at desc);

create table entitlements (
    user_id     uuid not null references profiles(id) on delete cascade,
    cosmetic    text not null,
    granted_at  timestamptz not null default now(),
    primary key (user_id, cosmetic)
);
