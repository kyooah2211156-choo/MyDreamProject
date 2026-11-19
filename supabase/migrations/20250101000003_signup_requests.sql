-- 2단계: 유치원 가입 신청과 운영자 승인/반려
-- 신청, 승인, 반려는 모두 아래 함수로만 가능하다. 표에 직접 쓰는 권한은 주지 않는다.

create table public.signup_requests (
  id uuid primary key default gen_random_uuid(),
  applicant_id uuid not null references auth.users (id) on delete cascade,
  applicant_name text,
  applicant_email text,
  kindergarten_name text not null check (char_length(kindergarten_name) between 1 and 100),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  reject_reason text,
  kindergarten_id uuid references public.kindergartens (id),
  reviewed_by uuid references auth.users (id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

-- 한 사용자가 대기 중인 신청을 두 개 만들 수 없다.
create unique index signup_requests_one_pending
  on public.signup_requests (applicant_id) where status = 'pending';

alter table public.signup_requests enable row level security;

revoke all on public.signup_requests from anon, authenticated;
grant select on public.signup_requests to authenticated;

-- 신청자는 자기 신청만, 운영자는 전체를 본다.
create policy signup_requests_select on public.signup_requests
  for select to authenticated
  using (applicant_id = (select auth.uid()) or public.is_platform_admin());

-- 신청
create function public.submit_signup_request(p_kindergarten_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_name text := trim(p_kindergarten_name);
  v_id uuid;
  v_email text;
  v_display text;
begin
  if v_uid is null then
    raise exception 'login required' using errcode = '42501';
  end if;
  if v_name is null or char_length(v_name) not between 1 and 100 then
    raise exception 'invalid kindergarten name' using errcode = '22023';
  end if;
  if exists (
    select 1 from public.staff_memberships
    where user_id = v_uid and status in ('invited', 'active')
  ) then
    raise exception 'already belongs to a kindergarten';
  end if;

  select email into v_email from auth.users where id = v_uid;
  select display_name into v_display from public.profiles where id = v_uid;

  insert into public.signup_requests (applicant_id, applicant_name, applicant_email, kindergarten_name)
  values (v_uid, v_display, v_email, v_name)
  returning id into v_id;
  return v_id;
end;
$$;

-- 승인: 유치원(정상)을 만들고 신청자를 원장으로 등록한다.
create function public.approve_signup_request(p_request_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_req public.signup_requests;
  v_kg uuid;
begin
  if not public.is_platform_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select * into v_req from public.signup_requests where id = p_request_id for update;
  if not found then
    raise exception 'request not found';
  end if;
  if v_req.status <> 'pending' then
    raise exception 'request already processed';
  end if;

  insert into public.kindergartens (name, status, approved_at)
  values (v_req.kindergarten_name, 'active', now())
  returning id into v_kg;

  insert into public.staff_memberships (kindergarten_id, user_id, role, status)
  values (v_kg, v_req.applicant_id, 'director', 'active');

  update public.signup_requests
  set status = 'approved', kindergarten_id = v_kg,
      reviewed_by = (select auth.uid()), reviewed_at = now()
  where id = p_request_id;

  return v_kg;
end;
$$;

-- 반려
create function public.reject_signup_request(p_request_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
begin
  if not public.is_platform_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select status into v_status from public.signup_requests where id = p_request_id for update;
  if not found then
    raise exception 'request not found';
  end if;
  if v_status <> 'pending' then
    raise exception 'request already processed';
  end if;

  update public.signup_requests
  set status = 'rejected', reject_reason = nullif(trim(p_reason), ''),
      reviewed_by = (select auth.uid()), reviewed_at = now()
  where id = p_request_id;
end;
$$;

revoke execute on function
  public.submit_signup_request(text),
  public.approve_signup_request(uuid),
  public.reject_signup_request(uuid, text)
  from public, anon;
grant execute on function
  public.submit_signup_request(text),
  public.approve_signup_request(uuid),
  public.reject_signup_request(uuid, text)
  to authenticated;
