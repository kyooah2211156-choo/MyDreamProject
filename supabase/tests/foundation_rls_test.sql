-- 1단계 보안 테스트. 가짜 사용자를 만들어 권한을 확인하고, 마지막에 전부 되돌린다(rollback).
-- 하나라도 어긋나면 에러가 나고, 모두 통과하면 마지막에 'ALL PASSED'가 보인다.

begin;

-- 가짜 사용자
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000a001', 'director-a@test.local'),
  ('00000000-0000-0000-0000-00000000a002', 'teacher-a@test.local'),
  ('00000000-0000-0000-0000-00000000b001', 'director-b@test.local'),
  ('00000000-0000-0000-0000-0000000000ff', 'admin@test.local'),
  ('00000000-0000-0000-0000-0000000000ee', 'nobody@test.local');

insert into public.kindergartens (id, name, status) values
  ('11111111-1111-1111-1111-111111111111', 'A 유치원', 'active'),
  ('22222222-2222-2222-2222-222222222222', 'B 유치원', 'active');

insert into public.staff_memberships (kindergarten_id, user_id, role, status) values
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-00000000a001', 'director', 'active'),
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-00000000a002', 'teacher', 'active'),
  ('22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-00000000b001', 'director', 'active');

insert into public.platform_admins (user_id) values ('00000000-0000-0000-0000-0000000000ff');

do $$
declare
  n int;
  kgA constant uuid := '11111111-1111-1111-1111-111111111111';
  kgB constant uuid := '22222222-2222-2222-2222-222222222222';
begin
  -- 1. A 원장: 자기 유치원 1곳, 직원 2명만 보인다
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000a001","role":"authenticated"}', true);
  set local role authenticated;
  select count(*) into n from public.kindergartens;
  assert n = 1, format('1-a: A 원장이 본 유치원 수 %s (기대 1)', n);
  select count(*) into n from public.kindergartens where id = kgB;
  assert n = 0, '1-b: A 원장이 B 유치원을 볼 수 있음';
  select count(*) into n from public.staff_memberships;
  assert n = 2, format('1-c: A 원장이 본 직원 수 %s (기대 2)', n);
  reset role;

  -- 2. A 선생님: 자기 소속 1건만 보이고, 유치원 정보를 바꿀 수 없다
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000a002","role":"authenticated"}', true);
  set local role authenticated;
  select count(*) into n from public.staff_memberships;
  assert n = 1, format('2-a: 선생님이 본 소속 수 %s (기대 1)', n);
  update public.kindergartens set status = 'terminated' where id = kgA;
  get diagnostics n = row_count;
  assert n = 0, '2-b: 선생님이 유치원 상태를 바꿈';
  -- 3단계부터 역할(role) 열은 아무도 바꿀 수 없다(열 권한 없음).
  begin
    update public.staff_memberships set role = 'director'
      where user_id = '00000000-0000-0000-0000-00000000a002';
    assert false, '2-c: 선생님이 자기 역할을 올림';
  exception when insufficient_privilege then null;
  end;
  reset role;

  -- 3. B 원장: B만 보이고, A 직원 정보는 못 바꾼다
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000b001","role":"authenticated"}', true);
  set local role authenticated;
  select count(*) into n from public.kindergartens;
  assert n = 1, '3-a: B 원장이 본 유치원 수가 1이 아님';
  select count(*) into n from public.kindergartens where id = kgA;
  assert n = 0, '3-b: B 원장이 A 유치원을 볼 수 있음';
  update public.staff_memberships set status = 'left'
    where kindergarten_id = kgA;
  get diagnostics n = row_count;
  assert n = 0, '3-c: B 원장이 A 직원을 변경함';
  reset role;

  -- 4. 운영자: 유치원 전체는 보이고 직원 소속은 안 보이며, 상태는 바꿀 수 있다
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000ff","role":"authenticated"}', true);
  set local role authenticated;
  select count(*) into n from public.kindergartens;
  assert n = 2, format('4-a: 운영자가 본 유치원 수 %s (기대 2)', n);
  select count(*) into n from public.staff_memberships;
  assert n = 0, '4-b: 운영자가 직원 소속을 볼 수 있음';
  begin
    perform count(*) from public.platform_admins;
    assert false, '4-c: 운영자 목록이 API로 보임';
  exception when insufficient_privilege then
    null;
  end;
  reset role;

  -- 5. 소속 없는 사용자: 아무것도 안 보인다
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000ee","role":"authenticated"}', true);
  set local role authenticated;
  select count(*) into n from public.kindergartens;
  assert n = 0, '5-a: 소속 없는 사용자가 유치원을 봄';
  select count(*) into n from public.staff_memberships;
  assert n = 0, '5-b: 소속 없는 사용자가 소속 정보를 봄';
  reset role;

  -- 6. 로그인 전(anon)은 접근 자체가 거부된다
  set local role anon;
  begin
    perform count(*) from public.kindergartens;
    assert false, '6: anon이 유치원 표를 조회함';
  exception when insufficient_privilege then
    null;
  end;
  reset role;

  -- 7. 정지: 원장은 읽기만 되고 직원 변경은 막힌다
  update public.kindergartens set status = 'suspended' where id = kgA;
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000a001","role":"authenticated"}', true);
  set local role authenticated;
  select count(*) into n from public.kindergartens;
  assert n = 1, '7-a: 정지된 유치원이 원장에게 안 보임';
  update public.staff_memberships set status = 'left'
    where user_id = '00000000-0000-0000-0000-00000000a002';
  get diagnostics n = row_count;
  assert n = 0, '7-b: 정지 상태에서 직원 변경이 됨';
  reset role;

  -- 8. 정상으로 복귀: 원장은 선생님을 퇴사 처리할 수 있고, 본인은 못 바꾼다
  update public.kindergartens set status = 'active' where id = kgA;
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000a001","role":"authenticated"}', true);
  set local role authenticated;
  update public.staff_memberships set status = 'left'
    where user_id = '00000000-0000-0000-0000-00000000a001';
  get diagnostics n = row_count;
  assert n = 0, '8-a: 원장이 자기 자신을 변경함';
  update public.staff_memberships set status = 'left'
    where user_id = '00000000-0000-0000-0000-00000000a002';
  get diagnostics n = row_count;
  assert n = 1, '8-b: 원장이 선생님을 퇴사 처리하지 못함';
  reset role;

  -- 9. 퇴사한 선생님: 유치원도 소속도 즉시 안 보인다
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000a002","role":"authenticated"}', true);
  set local role authenticated;
  select count(*) into n from public.kindergartens;
  assert n = 0, '9-a: 퇴사한 선생님이 유치원을 봄';
  select count(*) into n from public.staff_memberships;
  assert n = 0, '9-b: 퇴사한 선생님이 소속 정보를 봄';
  reset role;

  -- 10. 해지: 원장도 접근 불가
  update public.kindergartens set status = 'terminated' where id = kgA;
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000a001","role":"authenticated"}', true);
  set local role authenticated;
  select count(*) into n from public.kindergartens;
  assert n = 0, '10-a: 해지된 유치원이 원장에게 보임';
  reset role;
end;
$$;

select 'ALL PASSED' as result;

rollback;
