-- 4단계: 강아지 등록, 보호자 초대와 연결
-- 권한 정리
--   읽기: 재직 중인 모든 직원(조회만 포함), 연결된 보호자는 자기 강아지만
--   등록/수정/보호자 연결: 원장 또는 permission='full' 선생님 (이 기준은 미확정이라 바꾸기 쉽게 함수 하나에 모아 둠)
--   유치원 정지: 읽기만 가능 / 해지: 직원과 보호자 모두 접근 불가

-- ---------------------------------------------------------------- 표
create table public.dogs (
  id uuid primary key default gen_random_uuid(),
  kindergarten_id uuid not null references public.kindergartens (id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 50),
  breed text check (breed is null or char_length(breed) <= 50),
  birth_date date,
  sex text not null default 'unknown' check (sex in ('male', 'female', 'unknown')),
  health_notes text check (health_notes is null or char_length(health_notes) <= 1000),
  created_by uuid default auth.uid() references auth.users (id),
  created_at timestamptz not null default now()
);
create index dogs_kindergarten_idx on public.dogs (kindergarten_id);

create table public.guardian_links (
  id uuid primary key default gen_random_uuid(),
  kindergarten_id uuid not null references public.kindergartens (id) on delete cascade,
  dog_id uuid not null references public.dogs (id) on delete cascade,
  guardian_id uuid not null references auth.users (id) on delete cascade,
  relation text not null check (char_length(relation) between 1 and 20),
  status text not null default 'active' check (status in ('active', 'revoked')),
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  unique (dog_id, guardian_id)
);
create index guardian_links_guardian_idx on public.guardian_links (guardian_id);

create table public.guardian_invitations (
  id uuid primary key default gen_random_uuid(),
  kindergarten_id uuid not null references public.kindergartens (id) on delete cascade,
  dog_id uuid not null references public.dogs (id) on delete cascade,
  email text not null check (email = lower(email) and char_length(email) between 3 and 254),
  relation text not null check (char_length(relation) between 1 and 20),
  token_hash text not null unique,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'revoked')),
  expires_at timestamptz not null,
  created_by uuid not null references auth.users (id),
  accepted_by uuid references auth.users (id),
  accepted_at timestamptz,
  created_at timestamptz not null default now()
);
create unique index guardian_invitations_one_pending
  on public.guardian_invitations (dog_id, email) where status = 'pending';

-- ---------------------------------------------------------------- 판단 함수

-- 관리자(원장 또는 전체 권한 선생님). 읽기용: 정상 또는 정지 상태
create function public.is_manager_of_kg(kg uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.staff_memberships m
    join public.kindergartens k on k.id = m.kindergarten_id
    where m.kindergarten_id = kg
      and m.user_id = (select auth.uid())
      and m.status = 'active'
      and k.status in ('active', 'suspended')
      and (m.role = 'director' or m.permission = 'full')
  );
$$;

-- 관리자이면서 쓰기 가능: 정상 상태만
create function public.can_manage_kg(kg uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.staff_memberships m
    join public.kindergartens k on k.id = m.kindergarten_id
    where m.kindergarten_id = kg
      and m.user_id = (select auth.uid())
      and m.status = 'active'
      and k.status = 'active'
      and (m.role = 'director' or m.permission = 'full')
  );
$$;

-- 이 강아지의 현재 연결된 보호자인가 (유치원이 정상 또는 정지 상태일 때만)
create function public.is_guardian_of_dog(p_dog uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.guardian_links gl
    join public.kindergartens k on k.id = gl.kindergarten_id
    where gl.dog_id = p_dog
      and gl.guardian_id = (select auth.uid())
      and gl.status = 'active'
      and k.status in ('active', 'suspended')
  );
$$;

create function public.is_guardian_of_kg(p_kg uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.guardian_links gl
    join public.kindergartens k on k.id = gl.kindergarten_id
    where gl.kindergarten_id = p_kg
      and gl.guardian_id = (select auth.uid())
      and gl.status = 'active'
      and k.status in ('active', 'suspended')
  );
$$;

-- ---------------------------------------------------------------- 권한과 RLS

alter table public.dogs enable row level security;
alter table public.guardian_links enable row level security;
alter table public.guardian_invitations enable row level security;

revoke all on public.dogs, public.guardian_links, public.guardian_invitations
  from anon, authenticated;

grant select on public.dogs, public.guardian_links, public.guardian_invitations to authenticated;
grant insert (kindergarten_id, name, breed, birth_date, sex, health_notes)
  on public.dogs to authenticated;
grant update (name, breed, birth_date, sex, health_notes) on public.dogs to authenticated;

create policy dogs_select on public.dogs
  for select to authenticated
  using (public.can_read_kg(kindergarten_id) or public.is_guardian_of_dog(id));

create policy dogs_insert on public.dogs
  for insert to authenticated
  with check (public.can_manage_kg(kindergarten_id));

create policy dogs_update on public.dogs
  for update to authenticated
  using (public.can_manage_kg(kindergarten_id))
  with check (public.can_manage_kg(kindergarten_id));

create policy guardian_links_select on public.guardian_links
  for select to authenticated
  using (
    (guardian_id = (select auth.uid()) and public.is_guardian_of_dog(dog_id))
    or public.is_manager_of_kg(kindergarten_id)
  );

create policy guardian_invitations_select on public.guardian_invitations
  for select to authenticated
  using (public.is_manager_of_kg(kindergarten_id));

-- 보호자도 연결된 유치원의 이름과 상태는 볼 수 있어야 한다.
drop policy kindergartens_select on public.kindergartens;
create policy kindergartens_select on public.kindergartens
  for select to authenticated
  using (
    public.is_platform_admin()
    or public.can_read_kg(id)
    or public.is_guardian_of_kg(id)
  );

-- ---------------------------------------------------------------- 함수

create function public.create_guardian_invitation(p_dog uuid, p_email text, p_relation text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_kg uuid;
  v_email text := lower(trim(p_email));
  v_rel text := trim(p_relation);
  v_token text;
begin
  select kindergarten_id into v_kg from public.dogs where id = p_dog;
  if v_kg is null or not public.can_manage_kg(v_kg) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if v_email is null or v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' or char_length(v_email) > 254 then
    raise exception 'invalid email' using errcode = '22023';
  end if;
  if v_rel is null or char_length(v_rel) not between 1 and 20 then
    raise exception 'invalid relation' using errcode = '22023';
  end if;
  if exists (
    select 1
    from public.guardian_links gl
    join auth.users u on u.id = gl.guardian_id
    where gl.dog_id = p_dog and gl.status = 'active' and lower(u.email) = v_email
  ) then
    raise exception 'already linked';
  end if;

  update public.guardian_invitations
  set status = 'revoked'
  where dog_id = p_dog and email = v_email and status = 'pending' and expires_at < now();

  v_token := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');

  insert into public.guardian_invitations
    (kindergarten_id, dog_id, email, relation, token_hash, expires_at, created_by)
  values
    (v_kg, p_dog, v_email, v_rel,
     encode(sha256(convert_to(v_token, 'UTF8')), 'hex'),
     now() + interval '7 days', (select auth.uid()));

  return v_token;
end;
$$;

create function public.revoke_guardian_invitation(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_kg uuid;
begin
  select kindergarten_id into v_kg from public.guardian_invitations where id = p_id;
  if v_kg is null or not public.can_manage_kg(v_kg) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  update public.guardian_invitations set status = 'revoked'
  where id = p_id and status = 'pending';
  if not found then
    raise exception 'invitation not pending';
  end if;
end;
$$;

create function public.get_guardian_invitation_preview(p_token text)
returns table (kindergarten_name text, dog_name text, relation text, email_matches boolean, usable boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select k.name,
         d.name,
         i.relation,
         lower((select u.email from auth.users u where u.id = (select auth.uid()))) = i.email,
         i.status = 'pending' and i.expires_at > now() and k.status = 'active'
  from public.guardian_invitations i
  join public.kindergartens k on k.id = i.kindergarten_id
  join public.dogs d on d.id = i.dog_id
  where i.token_hash = encode(sha256(convert_to(p_token, 'UTF8')), 'hex');
$$;

create function public.accept_guardian_invitation(p_token text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_inv public.guardian_invitations;
  v_email text;
begin
  if v_uid is null then
    raise exception 'login required' using errcode = '42501';
  end if;

  select * into v_inv from public.guardian_invitations
  where token_hash = encode(sha256(convert_to(p_token, 'UTF8')), 'hex')
  for update;
  if not found or v_inv.status <> 'pending' or v_inv.expires_at <= now() then
    raise exception 'invalid invitation';
  end if;
  if not exists (select 1 from public.kindergartens where id = v_inv.kindergarten_id and status = 'active') then
    raise exception 'kindergarten not active';
  end if;

  select lower(email) into v_email from auth.users where id = v_uid;
  if v_email is distinct from v_inv.email then
    raise exception 'email mismatch';
  end if;

  insert into public.guardian_links (kindergarten_id, dog_id, guardian_id, relation, status)
  values (v_inv.kindergarten_id, v_inv.dog_id, v_uid, v_inv.relation, 'active')
  on conflict (dog_id, guardian_id)
  do update set status = 'active', relation = excluded.relation, revoked_at = null;

  update public.guardian_invitations
  set status = 'accepted', accepted_by = v_uid, accepted_at = now()
  where id = v_inv.id;

  return v_inv.dog_id;
end;
$$;

create function public.revoke_guardian_link(p_link_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_kg uuid;
begin
  select kindergarten_id into v_kg from public.guardian_links where id = p_link_id;
  if v_kg is null or not public.can_manage_kg(v_kg) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  update public.guardian_links set status = 'revoked', revoked_at = now()
  where id = p_link_id and status = 'active';
  if not found then
    raise exception 'link not active';
  end if;
end;
$$;

create function public.list_dog_guardians(p_dog uuid)
returns table (
  link_id uuid, guardian_id uuid, display_name text, email text,
  relation text, status text, created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_kg uuid;
begin
  select kindergarten_id into v_kg from public.dogs where id = p_dog;
  if v_kg is null or not public.is_manager_of_kg(v_kg) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  return query
    select gl.id, gl.guardian_id, p.display_name, u.email::text,
           gl.relation, gl.status, gl.created_at
    from public.guardian_links gl
    join auth.users u on u.id = gl.guardian_id
    left join public.profiles p on p.id = gl.guardian_id
    where gl.dog_id = p_dog
    order by gl.status, gl.created_at;
end;
$$;

revoke execute on function
  public.is_manager_of_kg(uuid), public.can_manage_kg(uuid),
  public.is_guardian_of_dog(uuid), public.is_guardian_of_kg(uuid),
  public.create_guardian_invitation(uuid, text, text),
  public.revoke_guardian_invitation(uuid),
  public.get_guardian_invitation_preview(text),
  public.accept_guardian_invitation(text),
  public.revoke_guardian_link(uuid),
  public.list_dog_guardians(uuid)
  from public, anon;
grant execute on function
  public.is_manager_of_kg(uuid), public.can_manage_kg(uuid),
  public.is_guardian_of_dog(uuid), public.is_guardian_of_kg(uuid),
  public.create_guardian_invitation(uuid, text, text),
  public.revoke_guardian_invitation(uuid),
  public.get_guardian_invitation_preview(text),
  public.accept_guardian_invitation(text),
  public.revoke_guardian_link(uuid),
  public.list_dog_guardians(uuid)
  to authenticated;
