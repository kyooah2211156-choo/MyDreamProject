import { Suspense } from "react";
import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { logout } from "./login/actions";
import { outlineButton, primaryButton } from "@/lib/ui";

type Membership = {
  role: "director" | "teacher";
  status: string;
  kindergartens: { name: string; status: string } | null;
};

async function HomeContent() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const [{ data: profile }, { data: isAdmin }, { data: memberData }, { data: requests }] =
    await Promise.all([
      supabase.from("profiles").select("display_name").maybeSingle(),
      supabase.rpc("is_platform_admin"),
      supabase
        .from("staff_memberships")
        .select("role, status, kindergartens(name, status)")
        .eq("status", "active"),
      supabase
        .from("signup_requests")
        .select("kindergarten_name, status, reject_reason")
        .order("created_at", { ascending: false })
        .limit(1),
    ]);

  const memberships = ((memberData ?? []) as unknown as Membership[]).filter((m) => m.kindergartens);
  const lastRequest = requests?.[0];

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-md flex-col justify-center gap-4 p-6">
      <h1 className="text-2xl font-bold">안녕하세요, {profile?.display_name || user?.email}님</h1>

      {isAdmin && (
        <div className="flex flex-col gap-2 rounded-xl border border-gray-200 p-4">
          <p className="font-medium">서비스 운영자</p>
          <Link href="/admin/requests" className={`${primaryButton} text-center`}>가입 신청 관리</Link>
          <Link href="/admin/kindergartens" className={`${outlineButton} text-center`}>유치원 이용 상태 관리</Link>
        </div>
      )}

      {memberships.map((m, i) => (
        <div key={i} className="rounded-xl border border-gray-200 p-4">
          <p className="text-lg font-medium">{m.kindergartens!.name}</p>
          <p className="text-sm text-gray-600">
            {m.role === "director" ? "원장" : "선생님"}
            {m.kindergartens!.status === "suspended" && " · 현재 이용 정지 (조회만 가능)"}
          </p>
        </div>
      ))}

      {memberships.length === 0 && !isAdmin && (
        <div className="flex flex-col gap-3 rounded-xl border border-gray-200 p-4">
          {lastRequest?.status === "pending" && (
            <p>
              <b>{lastRequest.kindergarten_name}</b> 가입 신청이 승인 대기 중입니다.
            </p>
          )}
          {lastRequest?.status === "rejected" && (
            <p className="text-red-700">
              신청이 반려되었습니다.{lastRequest.reject_reason && ` 사유: ${lastRequest.reject_reason}`}
            </p>
          )}
          {lastRequest?.status !== "pending" && (
            <Link href="/apply" className={`${primaryButton} text-center`}>유치원 가입 신청하기</Link>
          )}
        </div>
      )}

      <form action={logout}>
        <button className={`${outlineButton} w-full`}>로그아웃</button>
      </form>
    </main>
  );
}

export default function Home() {
  return (
    <Suspense fallback={<p className="p-6 text-gray-500">불러오는 중…</p>}>
      <HomeContent />
    </Suspense>
  );
}
