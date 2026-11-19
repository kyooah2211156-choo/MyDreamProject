-- 1단계: 사용자, 유치원, 직원 소속, 그리고 유치원 간 데이터 분리(RLS)
-- 상태 규칙
--   kindergartens.status: pending(승인 대기) / active(정상) / suspended(정지: 읽기 전용) / terminated(해지: 접근 차단)
--   staff_memberships.status: invited(초대) / active(재직) / left(퇴사)

-- ---------------------------------------------------------------- 테이블

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now()
);

create table public.platform_admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.kindergartens (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  status text not null default 'pending'
    check (status in ('pending', 'active', 'suspended', 'terminated')),
  approved_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.staff_memberships (
  id uuid primary key default gen_random_uuid(),
  kindergarten_id uuid not null references public.kindergartens (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null check (role in ('director', 'teacher')),
  status text not null default 'invited'
    check (status in ('invited', 'active', 'left')),
  created_at timestamptz not null default now(),
  unique (kindergarten_id, user_id)
);

create index staff_memberships_user_idx on public.staff_memberships (user_id);

-- 가입하면 profiles 행을 자동으로 만든다.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------- 판단 함수
-- security definer: RLS를 거치지 않고 직접 조회하므로 정책끼리 서로 꼬이지 않는다.

create function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.platform_admins where user_id = (select auth.uid())
  );
$$;

-- 읽기 가능: 재직 중인 직원이고 유치원이 정상 또는 정지 상태
create function public.can_read_kg(kg uuid)
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
  );
$$;

-- 쓰기 가능: 재직 중인 직원이고 유치원이 정상 상태 (정지되면 쓰기 막힘)
create function public.can_write_kg(kg uuid)
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
  );
$$;

create function public.is_director_of(kg uuid)
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
      and m.role = 'director'
      and m.status = 'active'
      and k.status in ('active', 'suspended')
  );
$$;

-- ---------------------------------------------------------------- 권한(grant)
-- 로그인 전(anon)은 아무것도 못 한다. 로그인한 사용자는 필요한 열만 수정할 수 있다.

revoke all on all tables in schema public from anon, authenticated;
alter default privileges in schema public revoke all on tables from anon;

grant select on public.profiles, public.kindergartens, public.staff_memberships
  to authenticated;
grant update (display_name) on public.profiles to authenticated;
grant update (name, status, approved_at) on public.kindergartens to authenticated;
grant update (role, status) on public.staff_memberships to authenticated;

revoke execute on function
  public.is_platform_admin(), public.can_read_kg(uuid),
  public.can_write_kg(uuid), public.is_director_of(uuid),
  public.handle_new_user()
  from public, anon;
grant execute on function
  public.is_platform_admin(), public.can_read_kg(uuid),
  public.can_write_kg(uuid), public.is_director_of(uuid)
  to authenticated;

-- ---------------------------------------------------------------- RLS 정책

alter table public.profiles enable row level security;
alter table public.platform_admins enable row level security; -- 정책 없음: API로는 아무도 못 봄
alter table public.kindergartens enable row level security;
alter table public.staff_memberships enable row level security;

-- profiles: 내 정보만
create policy profiles_select_own on public.profiles
  for select to authenticated
  using (id = (select auth.uid()));

create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- kindergartens: 운영자는 전체, 직원은 자기 유치원만(정상/정지). 변경은 운영자만.
create policy kindergartens_select on public.kindergartens
  for select to authenticated
  using (public.is_platform_admin() or public.can_read_kg(id));

create policy kindergartens_update_admin on public.kindergartens
  for update to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

-- staff_memberships: 퇴사하지 않은 내 소속, 또는 내가 원장인 유치원의 소속
create policy staff_select on public.staff_memberships
  for select to authenticated
  using (
    (user_id = (select auth.uid()) and status <> 'left')
    or public.is_director_of(kindergarten_id)
  );

-- 원장은 자기 유치원 직원의 역할/상태를 바꿀 수 있다(본인 제외, 정상 상태일 때만).
create policy staff_update_by_director on public.staff_memberships
  for update to authenticated
  using (
    public.is_director_of(kindergarten_id)
    and public.can_write_kg(kindergarten_id)
    and user_id <> (select auth.uid())
  )
  with check (
    public.is_director_of(kindergarten_id)
    and public.can_write_kg(kindergarten_id)
    and user_id <> (select auth.uid())
  );
