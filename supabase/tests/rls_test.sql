-- ChinGo — RLS proof.
--
-- README claims ChinGo never exposes where anyone is, and that a bond cannot be one-sided.
-- Those are testable claims about the database rather than about the client, and this
-- tests them. If any assertion here fails, the app is not safe to ship regardless of what
-- the UI does.
--
-- Everything runs inside a transaction that rolls back, so it is safe against a database
-- you are actively developing on.

\set ON_ERROR_STOP on
begin;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
values
  ('aaaaaaaa-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'a@test.local', 'x', now(), now(), now()),
  ('bbbbbbbb-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'b@test.local', 'x', now(), now(), now()),
  ('cccccccc-0000-4000-8000-000000000003', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'c@test.local', 'x', now(), now(), now());

-- Seeded as superuser so RLS is bypassed. The data genuinely exists, which is what makes a
-- later count of zero prove policy rather than absence.
insert into public.profiles (id, handle, is_16_plus) values
  ('aaaaaaaa-0000-4000-8000-000000000001', 'ana',  true),
  ('bbbbbbbb-0000-4000-8000-000000000002', 'bo',   true),
  ('cccccccc-0000-4000-8000-000000000003', 'cass', true);

-- A and B are friends. C is a stranger to both.
insert into public.bonds (lo, hi, meetups, distinct_places) values
  (least('aaaaaaaa-0000-4000-8000-000000000001'::uuid, 'bbbbbbbb-0000-4000-8000-000000000002'::uuid),
   greatest('aaaaaaaa-0000-4000-8000-000000000001'::uuid, 'bbbbbbbb-0000-4000-8000-000000000002'::uuid),
   4, 3);

insert into public.memories (owner, friend, at, place_label, happened_on) values
  ('aaaaaaaa-0000-4000-8000-000000000001', 'bbbbbbbb-0000-4000-8000-000000000002',
   st_point(-122.4271, 37.7595)::geography, 'Dolores Park', '2024-06-11'),
  ('bbbbbbbb-0000-4000-8000-000000000002', 'aaaaaaaa-0000-4000-8000-000000000001',
   st_point(126.9780, 37.5665)::geography, 'Euljiro', '2025-02-02');

insert into public.presence (user_id, cell) values
  ('aaaaaaaa-0000-4000-8000-000000000001', 'cell-alpha'),
  ('bbbbbbbb-0000-4000-8000-000000000002', 'cell-alpha'),
  ('cccccccc-0000-4000-8000-000000000003', 'cell-alpha');

-- ---------------------------------------------------------------------------
-- As A
-- ---------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"aaaaaaaa-0000-4000-8000-000000000001","role":"authenticated"}';

do $$
declare n integer;
begin
  -- 1. Memories are owner-only. Not even the friend who is *in* the memory may read it.
  select count(*) into n from public.memories;
  if n <> 1 then raise exception 'FAIL: A saw % memories, expected only their own 1', n; end if;
  raise notice 'PASS: memories are owner-only';

  select count(*) into n from public.memories
    where owner = 'bbbbbbbb-0000-4000-8000-000000000002';
  if n <> 0 then raise exception 'FAIL: A read % of B''s memories', n; end if;
  raise notice 'PASS: a friend cannot read your memories';

  -- 2. Presence is readable by nobody, including people in the same cell.
  select count(*) into n from public.presence
    where user_id <> 'aaaaaaaa-0000-4000-8000-000000000001';
  if n <> 0 then raise exception 'FAIL: A read % other presence rows', n; end if;
  raise notice 'PASS: nobody can read another person''s presence row';

  -- 3. ...but occupancy is still knowable, so the k-anonymity gate has its input.
  if public.cell_occupancy('cell-alpha') <> 3 then
    raise exception 'FAIL: cell occupancy came back %, expected 3', public.cell_occupancy('cell-alpha');
  end if;
  raise notice 'PASS: cell occupancy is countable without any row being readable';

  -- 4. Profiles: yourself and your bonded friends. Strangers are invisible -- there is no
  --    directory of people to browse.
  select count(*) into n from public.profiles;
  if n <> 2 then raise exception 'FAIL: A saw % profiles, expected self + 1 friend', n; end if;
  raise notice 'PASS: strangers are not browsable';

  select count(*) into n from public.profiles
    where id = 'cccccccc-0000-4000-8000-000000000003';
  if n <> 0 then raise exception 'FAIL: A read a stranger''s profile'; end if;
  raise notice 'PASS: a stranger''s profile is unreadable';

  -- 5. A catch may only be created unaccepted, and only by its initiator. Self-accepting
  --    would make "mutual consent" a client-side promise instead of a database rule.
  begin
    insert into public.catches (initiator, receiver, kind, cell, accepted_at)
    values ('aaaaaaaa-0000-4000-8000-000000000001',
            'cccccccc-0000-4000-8000-000000000003', 'snap', 'cell-alpha', now());
    raise exception 'FAIL: A created a pre-accepted catch';
  exception when insufficient_privilege or check_violation then
    raise notice 'PASS: a catch cannot be created already accepted';
  end;

  -- 6. You cannot forge a catch as someone else.
  begin
    insert into public.catches (initiator, receiver, kind, cell)
    values ('bbbbbbbb-0000-4000-8000-000000000002',
            'cccccccc-0000-4000-8000-000000000003', 'tag', 'cell-alpha');
    raise exception 'FAIL: A created a catch in B''s name';
  exception when insufficient_privilege then
    raise notice 'PASS: a catch cannot be forged on someone else''s behalf';
  end;

  -- 7. The ledger is append-only from the server. A client cannot mint itself credit.
  begin
    insert into public.ledger (user_id, delta, reason)
    values ('aaaaaaaa-0000-4000-8000-000000000001', 10000, 'free money');
    raise exception 'FAIL: A wrote to the ledger';
  exception when insufficient_privilege then
    raise notice 'PASS: the ledger is not client-writable';
  end;
end $$;

-- ---------------------------------------------------------------------------
-- As C, the stranger
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"cccccccc-0000-4000-8000-000000000003","role":"authenticated"}';

do $$
declare n integer;
begin
  select count(*) into n from public.memories;
  if n <> 0 then raise exception 'FAIL: a stranger read % memories', n; end if;
  raise notice 'PASS: a stranger reads no memories at all';

  select count(*) into n from public.bonds;
  if n <> 0 then raise exception 'FAIL: a stranger read % bonds', n; end if;
  raise notice 'PASS: a stranger cannot see who is friends with whom';

  select count(*) into n from public.profiles;
  if n <> 1 then raise exception 'FAIL: a stranger saw % profiles, expected only self', n; end if;
  raise notice 'PASS: a stranger sees only themselves';
end $$;

-- ---------------------------------------------------------------------------
-- Bond symmetry: the schema makes a one-sided friendship unrepresentable.
-- ---------------------------------------------------------------------------
reset role;

do $$
begin
  begin
    insert into public.bonds (lo, hi)
    values ('bbbbbbbb-0000-4000-8000-000000000002', 'aaaaaaaa-0000-4000-8000-000000000001');
    raise exception 'FAIL: a reversed duplicate bond was accepted';
  exception when check_violation or unique_violation then
    raise notice 'PASS: a bond cannot be stored twice or one-sidedly';
  end;
end $$;

rollback;
