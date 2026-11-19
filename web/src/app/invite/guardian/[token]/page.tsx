import { Suspense } from "react";
import { createClient } from "@/lib/supabase/server";
import { logout } from "@/app/login/actions";
import { acceptGuardianInvitation } from "../actions";
import { outlineButton, primaryButton } from "@/lib/ui";

async function GuardianInviteContent({
  params,
  searchParams,
}: {
  params: Promise<{ token: string }>;
  searchParams: Promise<{ error?: string }>;
}) {
  const { token } = await params;
  const { error } = await searchParams;
  const valid = /^[0-9a-f]{64}$/.test(token);

  let info:
    | { kindergarten_name: string; dog_name: string; relation: string; email_matches: boolean; usable: boolean }
    | undefined;
  if (valid) {
    const supabase = await createClient();
    const { data } = await supabase.rpc("get_guardian_invitation_preview", { p_token: token });
    info = data?.[0];
  }

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-md flex-col justify-center gap-4 p-6">
      <h1 className="text-2xl font-bold">보호자 초대</h1>
      {error && <p className="rounded-lg bg-red-50 p-3 text-sm text-red-700">{error}</p>}

      {!info && <p>유효하지 않은 초대 링크입니다.</p>}
      {info && !info.usable && <p>이미 사용했거나 만료, 취소된 초대입니다. 유치원에 새 초대를 요청해 주세요.</p>}
      {info?.usable && !info.email_matches && (
        <>
          <p>
            <b>{info.kindergarten_name}</b>의 초대입니다. 그런데 지금 로그인한 계정은 초대받은 이메일과 다릅니다.
            초대받은 이메일 계정으로 다시 로그인해 주세요.
          </p>
          <form action={logout}>
            <button className={`${outlineButton} w-full`}>로그아웃</button>
          </form>
        </>
      )}
      {info?.usable && info.email_matches && (
        <>
          <p>
            <b>{info.kindergarten_name}</b>에서 <b>{info.dog_name}</b>의 보호자({info.relation})로 초대했습니다.
            수락하면 {info.dog_name}의 정보와 알림장을 볼 수 있습니다.
          </p>
          <form action={acceptGuardianInvitation}>
            <input type="hidden" name="token" value={token} />
            <button className={`${primaryButton} w-full`}>초대 수락</button>
          </form>
        </>
      )}
    </main>
  );
}

export default function GuardianInvitePage(props: {
  params: Promise<{ token: string }>;
  searchParams: Promise<{ error?: string }>;
}) {
  return (
    <Suspense fallback={<p className="p-6 text-gray-500">불러오는 중…</p>}>
      <GuardianInviteContent {...props} />
    </Suspense>
  );
}
