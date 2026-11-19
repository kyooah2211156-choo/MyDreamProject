-- 3단계 테스트: 직원 초대, 권한, 퇴사. 마지막에 전부 되돌린다. 모두 통과하면 'ALL PASSED'.

begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000a001', 'director-a@test.local'),
  ('00000000-0000-0000-0000-00000000b001', 'director-b@test.local'),
  ('00000000-0000-0000-0000-0000000000c1', 't1@test.local'),
  ('00000000-0000-0000-0000-0000000000c2', 't2@test.local'),
  ('00000000-0000-0000-0000-0000000000c3', 't3@test.local'),
  ('00000000-0000-0000-0000-0000000000c4', 't4@test.local');

insert into public.kindergartens (id, name, status) values
  ('11111111-1111-1111-1111-111111111111', 'A 유치원', 'active'),
  ('22222222-2222-2222-2222-222222222222', 'B 유치원', 'active');

insert into public.staff_memberships (kindergarten_id, user_id, role, status) values
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-00000000a001', 'director', 'active'),
  ('22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-00000000b001', 'director', 'active'),
  ('22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-0000000000c2', 'teacher', 'active'),
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-0000000000c3', 'teacher', 'active');

do $$
declare
  kgA constant uuid := '11111111-1111-1111-1111-111111111111';
  kgB constant uuid := '22222222-2222-2222-2222-222222222222';
  dA constant text := '{"sub":"00000000-0000-0000-0000-00000000a001","role":"authenticated"}';
  dB constant text := '{"sub":"00000000-0000-0000-0000-00000000b001","role":"authenticated"}';
  t1 constant text := '{"sub":"00000000-0000-0000-0000-0000000000c1","role":"authenticated"}';
  t2 constant text := '{"sub":"00000000-0000-0000-0000-0000000000c2","role":"authenticated"}';
  t3 constant text := '{"sub":"00000000-0000-0000-0000-0000000000c3","role":"authenticated"}';
  t4 constant text := '{"sub":"00000000-0000-0000-0000-0000000000c4","role":"authenticated"}';
  n int;
  tok text;
  tok2 text;
  inv uuid;
  r record;
begin
  -- 1. 원장 A가 초대를 만든다 (이메일은 소문자로 정리된다)
  perform set_config('request.jwt.claims', dA, true);
  set local role authenticated;
  tok := public.create_staff_invitation(kgA, ' T1@Test.local ', 'standard');
  assert length(tok) >= 32, '1-a: 초대 비밀 값이 너무 짧음';
  select count(*) into n from public.staff_invitations;
  assert n = 1, '1-b: 원장이 초대를 못 봄';
  select count(*) into n from public.staff_invitations where token_hash = tok;
  assert n = 0, '1-c: 비밀 값이 그대로 저장됨';
  begin
    perform public.create_staff_invitation(kgA, 't1@test.local', 'view');
    assert false, '1-d: 같은 이메일 중복 초대가 허용됨';
  exception when unique_violation then null; end;
  begin
    perform public.create_staff_invitation(kgA, 'not-an-email', 'view');
    assert false, '1-e: 잘못된 이메일 허용';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.create_staff_invitation(kgA, 'x@test.local', 'admin');
    assert false, '1-f: 잘못된 권한 값 허용';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.create_staff_invitation(kgA, 't3@test.local', 'view');
    assert false, '1-g: 이미 재직 중인 직원을 초대함';
  exception when raise_exception then null; end;
  reset role;

  -- 2. 선생님과 다른 유치원 원장은 초대할 수 없고 초대 목록도 못 본다
  perform set_config('request.jwt.claims', t3, true);
  set local role authenticated;
  begin
    perform public.create_staff_invitation(kgA, 'n1@test.local', 'view');
    assert false, '2-a: 선생님이 초대함';
  exception when insufficient_privilege then null; end;
  select count(*) into n from public.staff_invitations;
  assert n = 0, '2-b: 선생님이 초대 목록을 봄';
  reset role;
  perform set_config('request.jwt.claims', dB, true);
  set local role authenticated;
  begin
    perform public.create_staff_invitation(kgA, 'n2@test.local', 'view');
    assert false, '2-c: 다른 유치원 원장이 초대함';
  exception when insufficient_privilege then null; end;
  select count(*) into n from public.staff_invitations;
  assert n = 0, '2-d: 다른 유치원 원장이 초대 목록을 봄';
  reset role;

  -- 3. 초대 수락
  perform set_config('request.jwt.claims', t1, true);
  set local role authenticated;
  select * into r from public.get_invitation_preview(tok);
  assert r.kindergarten_name = 'A 유치원' and r.email_matches and r.usable, '3-a: 미리보기 오류';
  reset role;
  perform set_config('request.jwt.claims', t4, true);
  set local role authenticated;
  begin
    perform public.accept_staff_invitation(tok);
    assert false, '3-b: 다른 이메일 사용자가 수락함';
  exception when raise_exception then null; end;
  begin
    perform public.accept_staff_invitation('wrong-token');
    assert false, '3-c: 잘못된 토큰이 수락됨';
  exception when raise_exception then null; end;
  reset role;
  perform set_config('request.jwt.claims', t1, true);
  set local role authenticated;
  assert public.accept_staff_invitation(tok) = kgA, '3-d: 수락 결과 오류';
  select count(*) into n from public.kindergartens where id = kgA;
  assert n = 1, '3-e: 수락 후 유치원이 안 보임';
  begin
    perform public.accept_staff_invitation(tok);
    assert false, '3-f: 사용한 초대가 다시 수락됨';
  exception when raise_exception then null; end;
  reset role;

  -- 4. 이미 다른 유치원에 소속된 사람은 수락할 수 없다
  perform set_config('request.jwt.claims', dA, true);
  set local role authenticated;
  tok2 := public.create_staff_invitation(kgA, 't2@test.local', 'view');
  reset role;
  perform set_config('request.jwt.claims', t2, true);
  set local role authenticated;
  begin
    perform public.accept_staff_invitation(tok2);
    assert false, '4: 다른 유치원 소속자가 수락함';
  exception when raise_exception then null; end;
  reset role;

  -- 5. 만료된 초대는 수락할 수 없다
  perform set_config('request.jwt.claims', dA, true);
  set local role authenticated;
  tok := public.create_staff_invitation(kgA, 't4@test.local', 'view');
  reset role;
  update public.staff_invitations set expires_at = now() - interval '1 minute'
    where email = 't4@test.local';
  perform set_config('request.jwt.claims', t4, true);
  set local role authenticated;
  begin
    perform public.accept_staff_invitation(tok);
    assert false, '5: 만료된 초대가 수락됨';
  exception when raise_exception then null; end;
  reset role;

  -- 6. 취소된 초대는 수락할 수 없고, 선생님은 취소할 수 없다
  perform set_config('request.jwt.claims', dA, true);
  set local role authenticated;
  tok := public.create_staff_invitation(kgA, 't4@test.local', 'view'); -- 만료분은 정리되고 새로 만들어짐
  select id into inv from public.staff_invitations
    where email = 't4@test.local' and status = 'pending';
  reset role;
  perform set_config('request.jwt.claims', t3, true);
  set local role authenticated;
  begin
    perform public.revoke_staff_invitation(inv);
    assert false, '6-a: 선생님이 초대를 취소함';
  exception when insufficient_privilege then null; end;
  reset role;
  perform set_config('request.jwt.claims', dA, true);
  set local role authenticated;
  perform public.revoke_staff_invitation(inv);
  reset role;
  perform set_config('request.jwt.claims', t4, true);
  set local role authenticated;
  begin
    perform public.accept_staff_invitation(tok);
    assert false, '6-b: 취소된 초대가 수락됨';
  exception when raise_exception then null; end;
  reset role;

  -- 7. 직원 목록은 원장만 볼 수 있다 (원장 A, 선생님 t3, 선생님 t1)
  perform set_config('request.jwt.claims', dA, true);
  set local role authenticated;
  select count(*) into n from public.list_staff(kgA);
  assert n = 3, format('7-a: 직원 수 %s (기대 3)', n);
  select count(*) into n from public.list_staff(kgA) where email is null;
  assert n = 0, '7-b: 이메일이 비어 있음';
  begin
    perform * from public.list_staff(kgB);
    assert false, '7-c: 원장이 다른 유치원 직원 목록을 봄';
  exception when insufficient_privilege then null; end;
  reset role;
  perform set_config('request.jwt.claims', t3, true);
  set local role authenticated;
  begin
    perform * from public.list_staff(kgA);
    assert false, '7-d: 선생님이 직원 목록을 봄';
  exception when insufficient_privilege then null; end;
  reset role;

  -- 8. 권한 변경
  perform set_config('request.jwt.claims', dA, true);
  set local role authenticated;
  update public.staff_memberships set permission = 'view'
    where user_id = '00000000-0000-0000-0000-0000000000c3';
  get diagnostics n = row_count;
  assert n = 1, '8-a: 원장이 권한을 못 바꿈';
  begin
    update public.staff_memberships set permission = 'admin'
      where user_id = '00000000-0000-0000-0000-0000000000c3';
    assert false, '8-b: 잘못된 권한 값 허용';
  exception when check_violation then null; end;
  begin
    update public.staff_memberships set role = 'director'
      where user_id = '00000000-0000-0000-0000-0000000000c3';
    assert false, '8-c: 원장이 역할을 바꿈';
  exception when insufficient_privilege then null; end;
  reset role;
  perform set_config('request.jwt.claims', dB, true);
  set local role authenticated;
  update public.staff_memberships set permission = 'full'
    where user_id = '00000000-0000-0000-0000-0000000000c3';
  get diagnostics n = row_count;
  assert n = 0, '8-d: 다른 유치원 원장이 권한을 바꿈';
  reset role;
  perform set_config('request.jwt.claims', t3, true);
  set local role authenticated;
  update public.staff_memberships set permission = 'full'
    where user_id = '00000000-0000-0000-0000-0000000000c3';
  get diagnostics n = row_count;
  assert n = 0, '8-e: 선생님이 스스로 권한을 올림';
  reset role;

  -- 9. 퇴사 처리: 즉시 접근 불가
  perform set_config('request.jwt.claims', dA, true);
  set local role authenticated;
  update public.staff_memberships set status = 'left'
    where user_id = '00000000-0000-0000-0000-0000000000c3';
  get diagnostics n = row_count;
  assert n = 1, '9-a: 퇴사 처리가 안 됨';
  begin
    update public.staff_memberships set status = 'invited'
      where user_id = '00000000-0000-0000-0000-0000000000c1';
    assert false, '9-b: 상태를 invited로 바꿈';
  exception when insufficient_privilege then null; end;
  reset role;
  perform set_config('request.jwt.claims', t3, true);
  set local role authenticated;
  select count(*) into n from public.kindergartens;
  assert n = 0, '9-c: 퇴사한 직원이 유치원을 봄';
  select count(*) into n from public.staff_memberships;
  assert n = 0, '9-d: 퇴사한 직원이 소속 정보를 봄';
  reset role;

  -- 10. 퇴사한 직원을 다시 초대하면 같은 소속이 되살아난다
  perform set_config('request.jwt.claims', dA, true);
  set local role authenticated;
  tok := public.create_staff_invitation(kgA, 't3@test.local', 'full');
  reset role;
  perform set_config('request.jwt.claims', t3, true);
  set local role authenticated;
  perform public.accept_staff_invitation(tok);
  select count(*) into n from public.staff_memberships
    where user_id = '00000000-0000-0000-0000-0000000000c3' and status = 'active' and permission = 'full';
  assert n = 1, '10-a: 재초대 후 소속이 복구되지 않음';
  reset role;
  select count(*) into n from public.staff_memberships
    where user_id = '00000000-0000-0000-0000-0000000000c3';
  assert n = 1, '10-b: 소속 행이 중복됨';

  -- 11. 정지된 유치원에서는 초대할 수 없다
  update public.kindergartens set status = 'suspended' where id = kgA;
  perform set_config('request.jwt.claims', dA, true);
  set local role authenticated;
  begin
    perform public.create_staff_invitation(kgA, 'n3@test.local', 'view');
    assert false, '11: 정지된 유치원에서 초대됨';
  exception when insufficient_privilege then null; end;
  reset role;

  -- 12. 로그인 전(anon)은 초대 함수를 실행할 수 없다
  set local role anon;
  begin
    perform public.create_staff_invitation(kgA, 'n4@test.local', 'view');
    assert false, '12: 익명이 초대함';
  exception when insufficient_privilege then null; end;
  reset role;
end;
$$;

select 'ALL PASSED' as result;

rollback;
