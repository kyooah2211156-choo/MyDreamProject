import { Suspense } from "react";
import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { ConfirmButton } from "@/components/ConfirmButton";
import { InviteForm } from "@/components/InviteForm";
import { leaveStaff, revokeInvitation, updatePermission } from "./actions";
import { dangerButton, outlineButton } from "@/lib/ui";

const permissionLabel: Record<string, string> = { view: "조회만", standard: "출결 + 알림장", full: "전체" };

type Staff = {
  membership_id: string;
  display_name: string | null;
  email: string;
  role: "director" | "teacher";
  status: "active" | "left";
  permission: string;
};
type Invitation = { id: string; email: string; permission: string; expires_at: string };

async function StaffContent({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const { error } = await searchParams;
  const supabase = await createClient();

  const { data: mine } = await supabase
    .from("staff_memberships")
    .select("kindergarten_id, kindergartens(name, status)")
    .eq("role", "director")
    .eq("status", "active")
    .limit(1);
  const kg = mine?.[0] as unknown as
    | { kindergarten_id: string; kindergartens: { name: string; status: string } | null }
    | undefined;
  if (!kg?.kindergartens) redirect("/");

  const [{ data: staffData }, { data: invData }] = await Promise.all([
    supabase.rpc("list_staff", { p_kg: kg.kindergarten_id }),
    supabase
      .from("staff_invitations")
      .select("id, email, permission, expires_at")
      .eq("status", "pending")
      .order("created_at", { ascending: false }),
  ]);
  const staff = (staffData ?? []) as Staff[];
  const invitations = ((invData ?? []) as Invitation[]).filter((i) => new Date(i.expires_at) > new Date());
  const suspended = kg.kindergartens.status === "suspended";

  return (
    <div className="mx-auto flex min-h-screen w-full max-w-2xl flex-col gap-6 p-4 md:p-8">
      <nav className="flex items-center gap-4 border-b border-gray-200 pb-3">
        <Link href="/" className="text-gray-600">홈</Link>
        <span className="font-medium">직원 관리 · {kg.kindergartens.name}</span>
      </nav>
      {error && <p className="rounded-lg bg-red-50 p-3 text-sm text-red-700">{error}</p>}
      {suspended && (
        <p className="rounded-lg bg-yellow-50 p-3 text-sm text-yellow-800">
          이용이 정지된 상태입니다. 직원 목록은 볼 수 있지만 초대와 변경은 할 수 없습니다.
        </p>
      )}

      <section className="flex flex-col gap-3">
        <h2 className="text-lg font-semibold">직원 초대</h2>
        {!suspended && <InviteForm kindergartenId={kg.kindergarten_id} />}
        {invitations.length > 0 && (
          <div className="flex flex-col gap-2">
            <p className="text-sm font-medium text-gray-700">초대 대기 중</p>
            {invitations.map((i) => (
              <div key={i.id} className="flex flex-wrap items-center justify-between gap-2 rounded-xl border border-gray-200 p-3">
                <div>
                  <p>{i.email}</p>
                  <p className="text-sm text-gray-500">
                    {permissionLabel[i.permission]} · {new Date(i.expires_at).toLocaleDateString("ko-KR")}까지
                  </p>
                </div>
                {!suspended && (
                  <form action={revokeInvitation}>
                    <input type="hidden" name="id" value={i.id} />
                    <ConfirmButton message={`${i.email} 초대를 취소할까요?`} className={outlineButton}>
                      취소
                    </ConfirmButton>
                  </form>
                )}
              </div>
            ))}
          </div>
        )}
      </section>

      <section className="flex flex-col gap-3">
        <h2 className="text-lg font-semibold">직원 목록</h2>
        {staff.map((s) => (
          <div key={s.membership_id} className="flex flex-col gap-3 rounded-xl border border-gray-200 p-4">
            <div>
              <p className="text-lg font-medium">
                {s.display_name || "(이름 없음)"}{" "}
                <span className="text-sm text-gray-600">
                  {s.role === "director" ? "원장" : s.status === "left" ? "퇴사" : "선생님"}
                </span>
              </p>
              <p className="text-sm text-gray-600">{s.email}</p>
              {s.role === "teacher" && s.status === "active" && (
                <p className="text-sm text-gray-500">권한: {permissionLabel[s.permission]}</p>
              )}
            </div>
            {s.role === "teacher" && s.status === "active" && !suspended && (
              <div className="flex flex-col gap-2 md:flex-row">
                <form action={updatePermission} className="flex flex-1 gap-2">
                  <input type="hidden" name="id" value={s.membership_id} />
                  <select name="permission" defaultValue={s.permission} className="flex-1 rounded-lg border border-gray-300 px-3 py-3">
                    <option value="view">조회만</option>
                    <option value="standard">출결 + 알림장</option>
                    <option value="full">전체</option>
                  </select>
                  <button className={outlineButton}>권한 저장</button>
                </form>
                <form action={leaveStaff}>
                  <input type="hidden" name="id" value={s.membership_id} />
                  <ConfirmButton
                    message={`${s.display_name || s.email} 님을 퇴사 처리할까요? 즉시 이 유치원 정보에 접근할 수 없게 됩니다.`}
                    className={`${dangerButton} w-full`}
                  >
                    퇴사 처리
                  </ConfirmButton>
                </form>
              </div>
            )}
          </div>
        ))}
      </section>
    </div>
  );
}

export default function StaffPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  return (
    <Suspense fallback={<p className="p-6 text-gray-500">불러오는 중…</p>}>
      <StaffContent searchParams={searchParams} />
    </Suspense>
  );
}
