-- 2단계 테스트: 신청, 승인, 반려. 마지막에 전부 되돌린다. 모두 통과하면 'ALL PASSED'.
-- 먼저 foundation 마이그레이션과 signup_requests 마이그레이션이 적용되어 있어야 한다.

begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'applicant1@test.local'),
  ('00000000-0000-0000-0000-0000000000a2', 'applicant2@test.local'),
  ('00000000-0000-0000-0000-0000000000ff', 'admin@test.local');
insert into public.platform_admins (user_id) values ('00000000-0000-0000-0000-0000000000ff');

do $$
declare
  n int;
  req1 uuid;
  req2 uuid;
  kg uuid;
  st text;
begin
  -- 1. 신청: 신청자 1이 신청한다
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
  set local role authenticated;
  req1 := public.submit_signup_request('해피독 유치원');
  select count(*) into n from public.signup_requests;
  assert n = 1, '1-a: 신청자가 자기 신청을 못 봄';

  -- 2. 대기 중 중복 신청은 거부된다
  begin
    perform public.submit_signup_request('또 신청');
    assert false, '2: 중복 신청이 허용됨';
  exception when unique_violation then null;
  end;

  -- 3. 신청 표에 직접 쓰기는 거부된다
  begin
    insert into public.signup_requests (applicant_id, kindergarten_name)
    values ('00000000-0000-0000-0000-0000000000a1', '직접 삽입');
    assert false, '3: 직접 삽입이 허용됨';
  exception when insufficient_privilege then null;
  end;

  -- 4. 신청자는 승인할 수 없다
  begin
    perform public.approve_signup_request(req1);
    assert false, '4: 일반 사용자가 승인함';
  exception when insufficient_privilege then null;
  end;
  reset role;

  -- 5. 다른 신청자는 남의 신청을 못 본다
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a2","role":"authenticated"}', true);
  set local role authenticated;
  select count(*) into n from public.signup_requests;
  assert n = 0, '5: 다른 사용자가 남의 신청을 봄';
  req2 := public.submit_signup_request('다른 유치원');
  reset role;

  -- 6. 운영자: 전체 신청을 보고 승인한다
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000ff","role":"authenticated"}', true);
  set local role authenticated;
  select count(*) into n from public.signup_requests;
  assert n = 2, '6-a: 운영자가 전체 신청을 못 봄';
  kg := public.approve_signup_request(req1);
  begin
    perform public.approve_signup_request(req1);
    assert false, '6-b: 이미 처리된 신청이 다시 승인됨';
  exception when raise_exception then null;
  end;

  -- 7. 운영자: 다른 신청을 반려한다
  perform public.reject_signup_request(req2, '서류 부족');
  select status into st from public.signup_requests where id = req2;
  assert st = 'rejected', '7: 반려되지 않음';
  reset role;

  -- 8. 승인된 신청자는 원장이 되어 자기 유치원을 본다
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
  set local role authenticated;
  select count(*) into n from public.kindergartens where id = kg and status = 'active';
  assert n = 1, '8-a: 승인 후 유치원이 안 보임';
  select count(*) into n from public.staff_memberships where role = 'director' and status = 'active';
  assert n = 1, '8-b: 원장 소속이 없음';
  -- 이미 소속이 있으면 새 신청을 할 수 없다
  begin
    perform public.submit_signup_request('두 번째 유치원');
    assert false, '8-c: 소속이 있는데 신청됨';
  exception when raise_exception then null;
  end;
  reset role;

  -- 9. 반려된 신청자는 유치원이 없고, 다시 신청할 수 있다
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a2","role":"authenticated"}', true);
  set local role authenticated;
  select count(*) into n from public.kindergartens;
  assert n = 0, '9-a: 반려된 신청자가 유치원을 봄';
  perform public.submit_signup_request('다시 신청');
  reset role;

  -- 10. 로그인 전(anon)은 함수를 실행할 수 없다
  set local role anon;
  begin
    perform public.submit_signup_request('익명');
    assert false, '10: 익명이 신청함';
  exception when insufficient_privilege then null;
  end;
  reset role;
end;
$$;

select 'ALL PASSED' as result;

rollback;
