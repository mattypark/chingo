-- Row level security. Deny by default, every table, no exceptions.
--
-- This file is the product's actual safety guarantee. Everything the UI does to protect
-- people -- ghost mode, the k-anonymity floor, memories being private -- is a convenience
-- on top of what is enforced here. If a policy in this file is wrong, no amount of client
-- code fixes it.
--
-- `(select auth.uid())` is wrapped once per policy rather than called inline: Postgres
-- then evaluates it a single time instead of once per row, which is the difference between
-- a fast index scan and a sequential one on every query in the app.

alter table profiles          enable row level security;
alter table profiles          force row level security;
alter table friend_codes      enable row level security;
alter table friend_codes      force row level security;
alter table bonds             enable row level security;
alter table bonds             force row level security;
alter table catches           enable row level security;
alter table catches           force row level security;
alter table card_moves        enable row level security;
alter table card_moves        force row level security;
alter table memories          enable row level security;
alter table memories          force row level security;
alter table presence          enable row level security;
alter table presence          force row level security;
alter table blocks            enable row level security;
alter table blocks            force row level security;
alter table reports           enable row level security;
alter table reports           force row level security;
alter table sponsored_zones   enable row level security;
alter table sponsored_zones   force row level security;
alter table zone_visits       enable row level security;
alter table zone_visits       force row level security;
alter table ledger            enable row level security;
alter table ledger            force row level security;
alter table entitlements      enable row level security;
alter table entitlements      force row level security;

-- Is there a bond between me and them, in either direction?
create or replace function is_bonded(other uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
    select exists (
        select 1 from bonds
        where (lo, hi) = (least((select auth.uid()), other), greatest((select auth.uid()), other))
    )
$$;

create or replace function is_blocked_either_way(other uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
    select exists (
        select 1 from blocks
        where (blocker = (select auth.uid()) and blocked = other)
           or (blocker = other and blocked = (select auth.uid()))
    )
$$;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------

-- Yourself, always. Other people only once you are bonded and neither of you has blocked
-- the other. There is deliberately no public directory: you cannot browse strangers.
create policy profiles_select on profiles for select
    using (
        id = (select auth.uid())
        or (is_bonded(id) and not is_blocked_either_way(id))
    );

create policy profiles_insert on profiles for insert
    with check (id = (select auth.uid()));

create policy profiles_update on profiles for update
    using (id = (select auth.uid()))
    with check (id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- friend_codes -- write-only to the world
-- ---------------------------------------------------------------------------

-- You can read only your own codes. Redeeming someone else's happens through a
-- security-definer function, so a code cannot be enumerated by querying the table.
create policy friend_codes_own on friend_codes for all
    using (owner = (select auth.uid()))
    with check (owner = (select auth.uid()));

create or replace function redeem_friend_code(input_code text)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
    target uuid;
    me uuid := (select auth.uid());
begin
    select owner into target from friend_codes
    where code = upper(input_code) and expires_at > now();

    if target is null then
        raise exception 'code_invalid';
    end if;
    if target = me then
        raise exception 'code_is_your_own';
    end if;
    if is_blocked_either_way(target) then
        -- Deliberately the same error as an invalid code. Telling someone they have been
        -- blocked is itself information they can act on.
        raise exception 'code_invalid';
    end if;

    insert into bonds (lo, hi)
    values (least(me, target), greatest(me, target))
    on conflict do nothing;

    return target;
end;
$$;

-- ---------------------------------------------------------------------------
-- bonds, catches, card moves
-- ---------------------------------------------------------------------------

create policy bonds_select on bonds for select
    using (lo = (select auth.uid()) or hi = (select auth.uid()));

-- Bonds are only ever written by redeem_friend_code and the catch acceptance path, both
-- security definer. Nothing writes this table directly.

create policy catches_select on catches for select
    using (initiator = (select auth.uid()) or receiver = (select auth.uid()));

create policy catches_insert on catches for insert
    with check (
        initiator = (select auth.uid())
        and not is_blocked_either_way(receiver)
        -- An unaccepted catch is a request, so it may only ever be created unaccepted.
        -- Accepting is the receiver's action alone, through accept_catch().
        and accepted_at is null
    );

create or replace function accept_catch(catch_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
    c catches%rowtype;
    me uuid := (select auth.uid());
begin
    select * into c from catches where id = catch_id;
    if c.id is null or c.receiver <> me then
        raise exception 'not_yours_to_accept';
    end if;
    if c.accepted_at is not null then
        return;
    end if;

    update catches set accepted_at = now() where id = catch_id;

    insert into bonds (lo, hi, meetups, distinct_places, first_met, last_met)
    values (
        least(c.initiator, me), greatest(c.initiator, me),
        case when c.kind = 'snap' then 1 else 0 end,
        case when c.kind = 'snap' then 1 else 0 end,
        c.happened_at, c.happened_at
    )
    on conflict (lo, hi) do update set
        -- Only a SNAP counts as a meetup. A TAG is an introduction, not an afternoon
        -- together, and the tier ladder would be trivial to farm if it counted.
        meetups = bonds.meetups + case when c.kind = 'snap' then 1 else 0 end,
        distinct_places = bonds.distinct_places + case
            when c.kind = 'snap' and not exists (
                select 1 from catches prior
                where prior.cell = c.cell
                  and prior.id <> c.id
                  and prior.accepted_at is not null
                  and ((prior.initiator = c.initiator and prior.receiver = c.receiver)
                    or (prior.initiator = c.receiver and prior.receiver = c.initiator))
            ) then 1 else 0 end,
        last_met = greatest(bonds.last_met, c.happened_at);
end;
$$;

-- Your own card's move text is readable by you and by the friend who wrote it.
create policy card_moves_select on card_moves for select
    using (subject = (select auth.uid()) or author = (select auth.uid()));

create policy card_moves_write on card_moves for insert
    with check (author = (select auth.uid()) and is_bonded(subject));

create policy card_moves_update on card_moves for update
    using (author = (select auth.uid()))
    with check (author = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- memories -- owner only, no exceptions
-- ---------------------------------------------------------------------------

-- The only precise coordinates in the database, and they are visible to exactly one
-- person. Not to the friend in the photo, not to anyone bonded, not to anyone at all.
create policy memories_own on memories for all
    using (owner = (select auth.uid()))
    with check (owner = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- presence -- writable by you, readable by nobody
-- ---------------------------------------------------------------------------

create policy presence_own on presence for all
    using (user_id = (select auth.uid()))
    with check (user_id = (select auth.uid()));

-- There is no select policy granting anyone sight of another row. Occupancy is reachable
-- only through cell_occupancy(), which returns a count and never a row, so the k-anonymity
-- floor cannot be worked around by querying the table directly.

-- ---------------------------------------------------------------------------
-- safety, money
-- ---------------------------------------------------------------------------

create policy blocks_own on blocks for all
    using (blocker = (select auth.uid()))
    with check (blocker = (select auth.uid()));

create policy reports_insert on reports for insert
    with check (reporter = (select auth.uid()));

-- Sponsored zones are the one genuinely public table: they describe places, not people.
create policy zones_public_read on sponsored_zones for select using (true);

create policy zone_visits_own on zone_visits for all
    using (user_id = (select auth.uid()))
    with check (user_id = (select auth.uid()));

create policy ledger_own_read on ledger for select
    using (user_id = (select auth.uid()));
-- No insert policy: the ledger is append-only from the server, never from a client.

create policy entitlements_own_read on entitlements for select
    using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------
--
-- RLS narrows what a role may touch; it never widens it. Without a grant the policies
-- above are unreachable and every query fails with "permission denied", so the two have to
-- be written together.
--
-- These are deliberately per-table and per-verb rather than a blanket grant on the schema:
-- the tables a client must never write to (ledger, entitlements, sponsored_zones) get
-- select and nothing else, which is a second, simpler lock behind the policies.

grant usage on schema public to anon, authenticated;

grant select, insert, update            on public.profiles        to authenticated;
grant select, insert, update, delete    on public.friend_codes    to authenticated;
grant select                            on public.bonds           to authenticated;
grant select, insert                    on public.catches         to authenticated;
grant select, insert, update, delete    on public.card_moves      to authenticated;
grant select, insert, update, delete    on public.memories        to authenticated;
grant select, insert, update, delete    on public.presence        to authenticated;
grant select, insert, delete            on public.blocks          to authenticated;
grant insert                            on public.reports         to authenticated;
grant select                            on public.sponsored_zones to authenticated, anon;
grant select, insert                    on public.zone_visits     to authenticated;

-- Read-only to every client. The ledger is written by the server alone, and entitlements
-- are granted by purchase flows, never claimed by the app.
grant select                            on public.ledger          to authenticated;
grant select                            on public.entitlements    to authenticated;

-- The security-definer functions are the only doors through the walls above, so they are
-- granted deliberately and individually.
grant execute on function public.redeem_friend_code(text)  to authenticated;
grant execute on function public.accept_catch(uuid)        to authenticated;
grant execute on function public.cell_occupancy(text)      to authenticated;
grant execute on function public.is_bonded(uuid)           to authenticated;
grant execute on function public.is_blocked_either_way(uuid) to authenticated;
