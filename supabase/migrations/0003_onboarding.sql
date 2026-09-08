-- Onboarding, accounts, and the doors a stranger may knock on.
--
-- The client finished onboarding on-device first (MeRecord in SwiftData), so the columns
-- here mirror what it already keeps: a handle, one line of bio, an accent index, the
-- develop-alert toggle, and when onboarding completed. The age gate stays a boolean --
-- AgeTier has exactly two cases, and storing the answer rather than the birthday is the
-- whole point of the gate.

-- ---------------------------------------------------------------------------
-- profiles: what onboarding writes
-- ---------------------------------------------------------------------------

alter table profiles
    -- Index into the palette, never a hex. Eight accents today; a ninth is a migration
    -- that widens the check, not a client crash -- Accent.at(_:) clamps on the way out.
    add column accent               smallint    not null default 0
                                    check (accent between 0 and 7),
    add column bio                  text        not null default ''
                                    check (char_length(bio) <= 140),
    add column wants_develop_alerts boolean     not null default true,
    add column onboarded_at         timestamptz,
    -- The database enforces the gate, not the screen: a profile cannot be marked onboarded
    -- unless the age assertion is true. A client that skips the step gets a check violation.
    add constraint profiles_onboarded_only_if_of_age
        check (onboarded_at is null or is_16_plus);

-- Handles are stored lowercase and compared lowercase. The check on the column already
-- refuses anything else; this makes the lookup functions below case-insensitive without
-- a functional index.
create or replace function handle_available(candidate text)
returns boolean
language sql stable security definer set search_path = public
as $$
    select lower(candidate) ~ '^[a-z0-9_]{2,20}$'
       and not exists (select 1 from profiles where handle = lower(candidate))
$$;
-- Yes, this reveals whether a handle is taken. So does the unique constraint on insert, one
-- round-trip later. A handle is a public address by design; a bio or a location is not.

-- ---------------------------------------------------------------------------
-- Adding someone by handle: a request, never a collection
-- ---------------------------------------------------------------------------

-- There is deliberately no public directory, so a client cannot look a handle up and read
-- the profile behind it. What it can do is knock: create a pending TAG that the other person
-- accepts or ignores. Nobody is ever collected.
--
-- Returns nothing and raises nothing, whether the handle exists, is your own, or belongs to
-- someone who has blocked you. Every one of those would otherwise be information about
-- another person handed to whoever asks.
create or replace function request_tag(target_handle text, at_cell text)
returns void
language plpgsql security definer set search_path = public
as $$
declare
    target uuid;
    me uuid := (select auth.uid());
begin
    select id into target from profiles
    where handle = lower(target_handle) and onboarded_at is not null;

    if target is null or target = me or is_blocked_either_way(target) then
        return;
    end if;

    insert into catches (initiator, receiver, kind, cell)
    values (me, target, 'tag', at_cell)
    on conflict do nothing;
end;
$$;

-- One pending request per pair, so a handle cannot be spammed with a hundred knocks.
create unique index catches_one_pending_tag_idx
    on catches (initiator, receiver)
    where kind = 'tag' and accepted_at is null;

-- ---------------------------------------------------------------------------
-- Blocks, for the presence server
-- ---------------------------------------------------------------------------

-- Everyone this person must not see and must not be seen by, in either direction. Called
-- by the presence worker with the service role when a phone connects, so a blocked pair
-- never appear on each other's map.
--
-- Granted to service_role ONLY. Handing this to a client would tell them who blocked them
-- -- the client could diff it against its own block list -- and that is exactly the
-- information a blocked person must not have.
create or replace function block_relations_for(subject uuid)
returns setof uuid
language sql stable security definer set search_path = public
as $$
    select blocked from blocks where blocker = subject
    union
    select blocker from blocks where blocked = subject
$$;

-- ---------------------------------------------------------------------------
-- Leaving
-- ---------------------------------------------------------------------------

-- App Store Review Guideline 5.1.1(v): an app that creates an account must let the person
-- delete it, in the app. Deleting the auth row cascades through profiles and from there
-- through every table that references it, so this is the one call and there is no second
-- table to remember.
create or replace function delete_me()
returns void
language sql security definer set search_path = public, auth
as $$
    delete from auth.users where id = (select auth.uid())
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

grant execute on function public.handle_available(text)          to authenticated, anon;
grant execute on function public.request_tag(text, text)         to authenticated;
grant execute on function public.delete_me()                     to authenticated;
-- Service role only. See the comment on the function.
revoke execute on function public.block_relations_for(uuid)      from public, anon, authenticated;
grant  execute on function public.block_relations_for(uuid)      to service_role;

-- The presence worker holds the service key, and this is the whole of what it may do
-- with it: read a profile to learn the handle, the accent, and whether the person is
-- discoverable and onboarded. Not write one. 0002 deliberately granted service_role
-- nothing at all, and this is the one exception -- a leaked service key should be able
-- to read profiles, not rewrite them.
grant usage  on schema public       to service_role;
grant select on public.profiles     to service_role;
