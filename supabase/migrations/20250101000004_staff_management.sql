-- 3단계: 직원 초대, 권한 관리, 퇴사 처리
-- 선생님 권한 묶음(permission): view(조회만) / standard(출결+알림장) / full(전체)
-- 원장은 permission 값과 상관없이 항상 전체 권한으로 취급한다.
-- 직원 소속이 하나뿐이라는 가정(한 사용자 = 한 유치원)은 미확정 사항이라 함수에서만 확인한다.

alter table public.staff_memberships
  add column permission text not null default 'standard'
  check (permission in ('view', 'standard', 'full'));

-- 원장이 바꿀 수 있는 열은 상태와 권한뿐이다(역할 변경 불가).
revoke update on public.staff_memberships from authenticated;
grant update (status, permission) on public.staff_memberships to authenticated;

-- 원장은 자기 유치원의 "선생님"만, 재직/퇴사 두 상태 사이에서만 바꿀 수 있다.
drop policy staff_update_by_director on public.staff_memberships;
create policy staff_update_by_director on public.staff_memberships
  for update to authenticated
  using (
    public.is_director_of(kindergarten_id)
    and public.can_write_kg(kindergarten_id)
    and user_id <> (select auth.uid())
    and role = 'teacher'
    and status in ('active', 'left')
  )
  with check (
    public.is_director_of(kindergarten_id)
    and public.can_write_kg(kindergarten_id)
    and user_id <> (select auth.uid())
    and role = 'teacher'
    and status in ('active', 'left')
  );

-- ---------------------------------------------------------------- 초대

create table public.staff_invitations (
  id uuid primary key default gen_random_uuid(),
  kindergarten_id uuid not null references public.kindergartens (id) on delete cascade,
  email text not null check (email = lower(email) and char_length(email) between 3 and 254),
  permission text not null default 'standard'
    check (permission in ('view', 'standard', 'full')),
  token_hash text not null unique, -- 초대 링크의 비밀 값은 저장하지 않고 해시만 저장한다.
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'revoked')),
  expires_at timestamptz not null,
  created_by uuid not null references auth.users (id),
  accepted_by uuid references auth.users (id),
  accepted_at timestamptz,
  created_at timestamptz not null default now()
);

create unique index staff_invitations_one_pending
  on public.staff_invitations (kindergarten_id, email) where status = 'pending';

alter table public.staff_invitations enable row level security;
revoke all on public.staff_invitations from anon, authenticated;
grant select on public.staff_invitations to authenticated;

create policy staff_invitations_select on public.staff_invitations
  for select to authenticated
  using (public.is_director_of(kindergarten_id));

-- 초대 만들기: 링크용 비밀 값(token)을 한 번만 돌려준다.
create function public.create_staff_invitation(p_kg uuid, p_email text, p_permission text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := lower(trim(p_email));
  v_token text;
begin
  if not (public.is_director_of(p_kg) and public.can_write_kg(p_kg)) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if v_email is null or v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' or char_length(v_email) > 254 then
    raise exception 'invalid email' using errcode = '22023';
  end if;
  if p_permission is null or p_permission not in ('view', 'standard', 'full') then
    raise exception 'invalid permission' using errcode = '22023';
  end if;
  if exists (
    select 1
    from auth.users u
    join public.staff_memberships m on m.user_id = u.id
    where lower(u.email) = v_email and m.kindergarten_id = p_kg and m.status = 'active'
  ) then
    raise exception 'already staff';
  end if;

  -- 만료된 이전 초대는 정리한다.
  update public.staff_invitations
  set status = 'revoked'
  where kindergarten_id = p_kg and email = v_email
    and status = 'pending' and expires_at < now();

  v_token := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');

  insert into public.staff_invitations
    (kindergarten_id, email, permission, token_hash, expires_at, created_by)
  values
    (p_kg, v_email, p_permission,
     encode(sha256(convert_to(v_token, 'UTF8')), 'hex'),
     now() + interval '7 days', (select auth.uid()));

  return v_token;
end;
$$;

create function public.revoke_staff_invitation(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_kg uuid;
begin
  select kindergarten_id into v_kg from public.staff_invitations where id = p_id;
  if v_kg is null or not (public.is_director_of(v_kg) and public.can_write_kg(v_kg)) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  update public.staff_invitations set status = 'revoked'
  where id = p_id and status = 'pending';
  if not found then
    raise exception 'invitation not pending';
  end if;
end;
$$;

-- 초대 링크를 연 사람에게 보여 줄 정보. 링크의 비밀 값을 아는 로그인 사용자만 호출 가능.
create function public.get_invitation_preview(p_token text)
returns table (kindergarten_name text, permission text, email_matches boolean, usable boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select k.name,
         i.permission,
         lower((select u.email from auth.users u where u.id = (select auth.uid()))) = i.email,
         i.status = 'pending' and i.expires_at > now() and k.status = 'active'
  from public.staff_invitations i
  join public.kindergartens k on k.id = i.kindergarten_id
  where i.token_hash = encode(sha256(convert_to(p_token, 'UTF8')), 'hex');
$$;

-- 초대 수락: 초대받은 이메일과 로그인 이메일이 같아야 한다.
create function public.accept_staff_invitation(p_token text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_inv public.staff_invitations;
  v_email text;
begin
  if v_uid is null then
    raise exception 'login required' using errcode = '42501';
  end if;

  select * into v_inv from public.staff_invitations
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

  if exists (
    select 1 from public.staff_memberships
    where user_id = v_uid and status in ('invited', 'active')
  ) then
    raise exception 'already belongs to a kindergarten';
  end if;

  insert into public.staff_memberships (kindergarten_id, user_id, role, status, permission)
  values (v_inv.kindergarten_id, v_uid, 'teacher', 'active', v_inv.permission)
  on conflict (kindergarten_id, user_id)
  do update set status = 'active', role = 'teacher', permission = excluded.permission;

  update public.staff_invitations
  set status = 'accepted', accepted_by = v_uid, accepted_at = now()
  where id = v_inv.id;

  return v_inv.kindergarten_id;
end;
$$;

-- 직원 목록(이름과 이메일 포함). 원장만 호출할 수 있다.
create function public.list_staff(p_kg uuid)
returns table (
  membership_id uuid, user_id uuid, display_name text, email text,
  role text, status text, permission text, created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_director_of(p_kg) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  return query
    select m.id, m.user_id, p.display_name, u.email::text,
           m.role, m.status, m.permission, m.created_at
    from public.staff_memberships m
    join auth.users u on u.id = m.user_id
    left join public.profiles p on p.id = m.user_id
    where m.kindergarten_id = p_kg and m.status in ('active', 'left')
    order by m.role, m.created_at;
end;
$$;

revoke execute on function
  public.create_staff_invitation(uuid, text, text),
  public.revoke_staff_invitation(uuid),
  public.get_invitation_preview(text),
  public.accept_staff_invitation(text),
  public.list_staff(uuid)
  from public, anon;
grant execute on function
  public.create_staff_invitation(uuid, text, text),
  public.revoke_staff_invitation(uuid),
  public.get_invitation_preview(text),
  public.accept_staff_invitation(text),
  public.list_staff(uuid)
  to authenticated;
