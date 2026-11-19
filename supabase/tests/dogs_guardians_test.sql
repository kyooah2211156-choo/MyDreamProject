-- 4단계 테스트: 강아지 등록, 보호자 연결과 공개 범위. 마지막에 전부 되돌린다. 모두 통과하면 'ALL PASSED'.

begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000a001', 'director-a@test.local'),
  ('00000000-0000-0000-0000-00000000b001', 'director-b@test.local'),
  ('00000000-0000-0000-0000-0000000000f1', 'full@test.local'),
  ('00000000-0000-0000-0000-0000000000f2', 'std@test.local'),
  ('00000000-0000-0000-0000-0000000000f3', 'view@test.local'),
  ('00000000-0000-0000-0000-0000000000d1', 'g1@test.local'),
  ('00000000-0000-0000-0000-0000000000d2', 'g2@test.local'),
  ('00000000-0000-0000-0000-0000000000d3', 'g3@test.local');

insert into public.kindergartens (id, name, status) values
  ('11111111-1111-1111-1111-111111111111', 'A 유치원', 'active'),
  ('22222222-2222-2222-2222-222222222222', 'B 유치원', 'active');

insert into public.staff_memberships (kindergarten_id, user_id, role, status, permission) values
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-00000000a001', 'director', 'active', 'standard'),
  ('22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-00000000b001', 'director', 'active', 'standard'),
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-0000000000f1', 'teacher', 'active', 'full'),
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-0000000000f2', 'teacher', 'active', 'standard'),
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-0000000000f3', 'teacher', 'active', 'view');

do $$
declare
  kgA constant uuid := '11111111-1111-1111-1111-111111111111';
  kgB constant uuid := '22222222-2222-2222-2222-222222222222';
  dA  constant text := '{"sub":"00000000-0000-0000-0000-00000000a001","role":"authenticated"}';
  dB  constant text := '{"sub":"00000000-0000-0000-0000-00000000b001","role":"authenticated"}';
  tF  constant text := '{"sub":"00000000-0000-0000-0000-0000000000f1","role":"authenticated"}';
  tS  constant text := '{"sub":"00000000-0000-0000-0000-0000000000f2","role":"authenticated"}';
  tV  constant text := '{"sub":"00000000-0000-0000-0000-0000000000f3","role":"authenticated"}';
  g1  constant text := '{"sub":"00000000-0000-0000-0000-0000000000d1","role":"authenticated"}';
  g2  constant text := '{"sub":"00000000-0000-0000-0000-0000000000d2","role":"authenticated"}';
  g3  constant text := '{"sub":"00000000-0000-0000-0000-0000000000d3","role":"authenticated"}';
  n int;
  coco uuid;
  mong uuid;
  tok text;
  tok2 text;
  linkid uuid;
  r record;
begin
  -- 1. 등록: 원장과 전체 권한 선생님만 가능
  perform set_config('request.jwt.claims', dA, true);
  set local role authenticated;
  insert into public.dogs (kindergarten_id, name, breed, sex, health_notes)
    values (kgA, '코코', '말티즈', 'female', '닭고기 알레르기') returning id into coco;
  reset role;
  perform set_config('request.jwt.claims', tF, true);
  set local role authenticated;
  insert into public.dogs (kindergarten_id, name) values (kgA, '몽이') returning id into mong;
  reset role;
  perform set_config('request.jwt.claims', tS, true);
  set local role authenticated;
  begin
    insert into public.dogs (kindergarten_id, name) values (kgA, '안되는강아지');
    assert false, '1-a: 출결+알림장 선생님이 등록함';
  exception when insufficient_privilege then null; end;
  reset role;
  perform set_config('request.jwt.claims', tV, true);
  set local role authenticated;
  begin
    insert into public.dogs (kindergarten_id, name) values (kgA, '안되는강아지');
    assert false, '1-b: 조회 전용 선생님이 등록함';
  exception when insufficient_privilege then null; end;
  reset role;
  perform set_config('request.jwt.claims', dB, true);
  set local role authenticated;
  begin
    insert into public.dogs (kindergarten_id, name) values (kgA, '남의유치원');
    assert false, '1-c: 다른 유치원 원장이 등록함';
  exception when insufficient_privilege then null; end;
  reset role;

  -- 2. 읽기: 같은 유치원 직원은 모두 읽고, 다른 유치원은 못 읽는다
  perform set_config('request.jwt.claims', tV, true);
  set local role authenticated;
  select count(*) into n from public.dogs;
  assert n = 2, format('2-a: 조회 전용 선생님이 본 강아지 수 %s (기대 2)', n);
  reset role;
  perform set_config('request.jwt.claims', dB, true);
  set local role authenticated;
  select count(*) into n from public.dogs;
  assert n = 0, '2-b: 다른 유치원 원장이 강아지를 봄';
  reset role;

  -- 3. 수정
  perform set_config('request.jwt.claims', tF, true);
  set local role authenticated;
  update public.dogs set breed = '푸들' where id = mong;
  get diagnostics n = row_count;
  assert n = 1, '3-a: 전체 권한 선생님이 수정 못함';
  begin
    update public.dogs set kindergarten_id = kgB where id = mong;
    assert false, '3-b: 강아지를 다른 유치원으로 옮김';
  exception when insufficient_privilege then null; end;
  reset role;
  perform set_config('request.jwt.claims', tS, true);
  set local role authenticated;
  update public.dogs set breed = '변경' where id = mong;
  get diagnostics n = row_count;
  assert n = 0, '3-c: 출결+알림장 선생님이 수정함';
  reset role;

  -- 4. 보호자 초대 만들기
  perform set_config('request.jwt.claims', tS, true);
  set local role authenticated;
  begin
    perform public.create_guardian_invitation(coco, 'g1@test.local', '엄마');
    assert false, '4-a: 권한 없는 선생님이 초대함';
  exception when insufficient_privilege then null; end;
  select count(*) into n from public.guardian_invitations;
  assert n = 0, '4-b: 권한 없는 선생님이 초대 목록을 봄';
  reset role;
  perform set_config('request.jwt.claims', dB, true);
  set local role authenticated;
  begin
    perform public.create_guardian_invitation(coco, 'g1@test.local', '엄마');
    assert false, '4-c: 다른 유치원 원장이 초대함';
  exception when insufficient_privilege then null; end;
  reset role;
  perform set_config('request.jwt.claims', dA, true);
  set local role authenticated;
  tok := public.create_guardian_invitation(coco, ' G1@Test.local ', '엄마');
  assert length(tok) >= 32, '4-d: 비밀 값이 너무 짧음';
  select count(*) into n from public.guardian_invitations where token_hash = tok;
  assert n = 0, '4-e: 비밀 값이 그대로 저장됨';
  begin
    perform public.create_guardian_invitation(coco, 'g1@test.local', '아빠');
    assert false, '4-f: 같은 이메일 중복 초대됨';
  exception when unique_violation then null; end;
  begin
    perform public.create_guardian_invitation(coco, 'bad', '아빠');
    assert false, '4-g: 잘못된 이메일 허용';
  exception when invalid_parameter_value then null; end;
  reset role;

  -- 5. 보호자 수락과 공개 범위
  perform set_config('request.jwt.claims', g2, true);
  set local role authenticated;
  begin
    perform public.accept_guardian_invitation(tok);
    assert false, '5-a: 다른 이메일 사용자가 수락함';
  exception when raise_exception then null; end;
  select count(*) into n from public.dogs;
  assert n = 0, '5-b: 연결 안 된 사용자가 강아지를 봄';
  reset role;
  perform set_config('request.jwt.claims', g1, true);
  set local role authenticated;
  select * into r from public.get_guardian_invitation_preview(tok);
  assert r.kindergarten_name = 'A 유치원' and r.dog_name = '코코' and r.email_matches and r.usable, '5-c: 미리보기 오류';
  assert public.accept_guardian_invitation(tok) = coco, '5-d: 수락 결과 오류';
  select count(*) into n from public.dogs;
  assert n = 1, format('5-e: 보호자가 본 강아지 수 %s (기대 1: 자기 강아지만)', n);
  select count(*) into n from public.dogs where id = mong;
  assert n = 0, '5-f: 보호자가 연결 안 된 강아지를 봄';
  select count(*) into n from public.kindergartens;
  assert n = 1, '5-g: 보호자가 자기 유치원을 못 봄';
  select count(*) into n from public.kindergartens where id = kgB;
  assert n = 0, '5-h: 보호자가 다른 유치원을 봄';
  select count(*) into n from public.guardian_links;
  assert n = 1, '5-i: 보호자가 자기 연결을 못 봄';
  select count(*) into n from public.staff_memberships;
  assert n = 0, '5-j: 보호자가 직원 소속을 봄';
  begin
    insert into public.dogs (kindergarten_id, name) values (kgA, '보호자가등록');
    assert false, '5-k: 보호자가 강아지를 등록함';
  exception when insufficient_privilege then null; end;
  update public.dogs set name = '바꿈' where id = coco;
  get diagnostics n = row_count;
  assert n = 0, '5-l: 보호자가 강아지를 수정함';
  begin
    perform * from public.list_dog_guardians(coco);
    assert false, '5-m: 보호자가 보호자 목록을 봄';
  exception when insufficient_privilege then null; end;
  begin
    perform public.create_guardian_invitation(coco, 'x@test.local', '친구');
    assert false, '5-n: 보호자가 다른 보호자를 초대함';
  exception when insufficient_privilege then null; end;
  begin
    perform public.accept_guardian_invitation(tok);
    assert false, '5-o: 사용한 초대가 다시 수락됨';
  exception when raise_exception then null; end;
  reset role;

  -- 6. 다른 보호자는 서로의 연결을 못 본다
  perform set_config('request.jwt.claims', tF, true);
  set local role authenticated;
  tok2 := public.create_guardian_invitation(mong, 'g2@test.local', '아빠');
  reset role;
  perform set_config('request.jwt.claims', g2, true);
  set local role authenticated;
  perform public.accept_guardian_invitation(tok2);
  select count(*) into n from public.dogs;
  assert n = 1, '6-a: g2가 본 강아지 수가 1이 아님';
  select count(*) into n from public.dogs where id = coco;
  assert n = 0, '6-b: g2가 남의 강아지를 봄';
  select count(*) into n from public.guardian_links;
  assert n = 1, '6-c: g2가 남의 연결을 봄';
  reset role;

  -- 7. 관리자는 보호자 목록(이메일 포함)을 본다
  perform set_config('request.jwt.claims', dA, true);
  set local role authenticated;
  select count(*) into n from public.list_dog_guardians(coco) where email = 'g1@test.local' and status = 'active';
  assert n = 1, '7-a: 보호자 목록 오류';
  select id into linkid from public.guardian_links where dog_id = coco;
  reset role;
  perform set_config('request.jwt.claims', tS, true);
  set local role authenticated;
  begin
    perform * from public.list_dog_guardians(coco);
    assert false, '7-b: 권한 없는 선생님이 보호자 목록을 봄';
  exception when insufficient_privilege then null; end;
  begin
    perform public.revoke_guardian_link(linkid);
    assert false, '7-c: 권한 없는 선생님이 연결을 해제함';
  exception when insufficient_privilege then null; end;
  reset role;

  -- 8. 연결 해제: 보호자는 즉시 아무것도 못 본다. 재초대하면 복구된다.
  perform set_config('request.jwt.claims', tF, true);
  set local role authenticated;
  perform public.revoke_guardian_link(linkid);
  reset role;
  perform set_config('request.jwt.claims', g1, true);
  set local role authenticated;
  select count(*) into n from public.dogs;
  assert n = 0, '8-a: 해제된 보호자가 강아지를 봄';
  select count(*) into n from public.guardian_links;
  assert n = 0, '8-b: 해제된 보호자가 연결을 봄';
  select count(*) into n from public.kindergartens;
  assert n = 0, '8-c: 해제된 보호자가 유치원을 봄';
  reset role;
  perform set_config('request.jwt.claims', dA, true);
  set local role authenticated;
  tok := public.create_guardian_invitation(coco, 'g1@test.local', '엄마');
  reset role;
  perform set_config('request.jwt.claims', g1, true);
  set local role authenticated;
  perform public.accept_guardian_invitation(tok);
  select count(*) into n from public.dogs;
  assert n = 1, '8-d: 재연결 후 강아지가 안 보임';
  reset role;
  select count(*) into n from public.guardian_links where dog_id = coco and guardian_id = '00000000-0000-0000-0000-0000000000d1';
  assert n = 1, '8-e: 연결 행이 중복됨';

  -- 9. 정지: 보호자는 읽기만, 직원은 등록과 초대 불가
  update public.kindergartens set status = 'suspended' where id = kgA;
  perform set_config('request.jwt.claims', g1, true);
  set local role authenticated;
  select count(*) into n from public.dogs;
  assert n = 1, '9-a: 정지 중 보호자가 강아지를 못 봄';
  reset role;
  perform set_config('request.jwt.claims', dA, true);
  set local role authenticated;
  begin
    insert into public.dogs (kindergarten_id, name) values (kgA, '정지중등록');
    assert false, '9-b: 정지 중 등록됨';
  exception when insufficient_privilege then null; end;
  begin
    perform public.create_guardian_invitation(coco, 'g3@test.local', '친구');
    assert false, '9-c: 정지 중 초대됨';
  exception when insufficient_privilege then null; end;
  select count(*) into n from public.dogs;
  assert n = 2, '9-d: 정지 중 원장이 강아지를 못 봄';
  reset role;

  -- 10. 해지: 보호자와 직원 모두 접근 불가
  update public.kindergartens set status = 'terminated' where id = kgA;
  perform set_config('request.jwt.claims', g1, true);
  set local role authenticated;
  select count(*) into n from public.dogs;
  assert n = 0, '10-a: 해지 후 보호자가 강아지를 봄';
  select count(*) into n from public.kindergartens;
  assert n = 0, '10-b: 해지 후 보호자가 유치원을 봄';
  reset role;
  perform set_config('request.jwt.claims', dA, true);
  set local role authenticated;
  select count(*) into n from public.dogs;
  assert n = 0, '10-c: 해지 후 원장이 강아지를 봄';
  reset role;
  update public.kindergartens set status = 'active' where id = kgA;

  -- 11. 퇴사한 선생님은 강아지를 못 본다
  update public.staff_memberships set status = 'left'
    where user_id = '00000000-0000-0000-0000-0000000000f1';
  perform set_config('request.jwt.claims', tF, true);
  set local role authenticated;
  select count(*) into n from public.dogs;
  assert n = 0, '11-a: 퇴사한 선생님이 강아지를 봄';
  begin
    insert into public.dogs (kindergarten_id, name) values (kgA, '퇴사후등록');
    assert false, '11-b: 퇴사한 선생님이 등록함';
  exception when insufficient_privilege then null; end;
  reset role;

  -- 12. 로그인 전(anon)은 접근 불가
  set local role anon;
  begin
    perform count(*) from public.dogs;
    assert false, '12: anon이 강아지 표를 조회함';
  exception when insufficient_privilege then null; end;
  reset role;
end;
$$;

select 'ALL PASSED' as result;

rollback;
