import { Suspense } from "react";
import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getStaffContext } from "@/lib/staff-context";
import { ConfirmButton } from "@/components/ConfirmButton";
import { DogFields } from "@/components/DogFields";
import { GuardianInviteForm } from "@/components/GuardianInviteForm";
import { revokeGuardianInvitation, revokeGuardianLink, updateDog } from "../actions";
import { dangerButton, outlineButton, primaryButton } from "@/lib/ui";

type Guardian = {
  link_id: string;
  display_name: string | null;
  email: string;
  relation: string;
  status: "active" | "revoked";
};
type Invitation = { id: string; email: string; relation: string; expires_at: string };

async function DogContent({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ error?: string; saved?: string }>;
}) {
  const { id } = await params;
  const { error, saved } = await searchParams;
  const ctx = await getStaffContext();
  if (!ctx) redirect("/");

  const supabase = await createClient();
  const { data: dog } = await supabase
    .from("dogs")
    .select("id, name, breed, birth_date, sex, health_notes")
    .eq("id", id)
    .eq("kindergarten_id", ctx.kgId)
    .maybeSingle();
  if (!dog) redirect("/dogs");

  let guardians: Guardian[] = [];
  let invitations: Invitation[] = [];
  if (ctx.canManage) {
    const [{ data: g }, { data: inv }] = await Promise.all([
      supabase.rpc("list_dog_guardians", { p_dog: id }),
      supabase
        .from("guardian_invitations")
        .select("id, email, relation, expires_at")
        .eq("dog_id", id)
        .eq("status", "pending")
        .order("created_at", { ascending: false }),
    ]);
    guardians = (g ?? []) as Guardian[];
    invitations = ((inv ?? []) as Invitation[]).filter((i) => new Date(i.expires_at) > new Date());
  }

  return (
    <div className="mx-auto flex min-h-screen w-full max-w-2xl flex-col gap-6 p-4 md:p-8">
      <Link href="/dogs" className="text-gray-600">← 강아지 목록</Link>
      <h1 className="text-2xl font-bold">{dog.name}</h1>
      {error && <p className="rounded-lg bg-red-50 p-3 text-sm text-red-700">{error}</p>}
      {saved && <p className="rounded-lg bg-green-50 p-3 text-sm text-green-700">저장했습니다.</p>}
      {ctx.kgStatus === "suspended" && (
        <p className="rounded-lg bg-yellow-50 p-3 text-sm text-yellow-800">이용이 정지된 상태라 조회만 가능합니다.</p>
      )}

      <section>
        <form action={updateDog} className="flex flex-col gap-3">
          <input type="hidden" name="id" value={dog.id} />
          <DogFields dog={dog} disabled={!ctx.canWrite} />
          {ctx.canWrite && <button className={primaryButton}>저장</button>}
        </form>
        {!ctx.canManage && (
          <p className="mt-2 text-sm text-gray-500">강아지 정보 수정은 원장 또는 전체 권한 선생님만 할 수 있습니다.</p>
        )}
      </section>

      {ctx.canManage && (
        <section className="flex flex-col gap-3">
          <h2 className="text-lg font-semibold">보호자</h2>
          {guardians.length === 0 && <p className="text-gray-500">연결된 보호자가 없습니다.</p>}
          {guardians.map((g) => (
            <div key={g.link_id} className="flex flex-wrap items-center justify-between gap-2 rounded-xl border border-gray-200 p-3">
              <div>
                <p className="font-medium">
                  {g.display_name || "(이름 없음)"} <span className="text-sm text-gray-600">{g.relation}</span>
                  {g.status === "revoked" && <span className="ml-2 text-sm text-red-700">연결 해제됨</span>}
                </p>
                <p className="text-sm text-gray-600">{g.email}</p>
              </div>
              {g.status === "active" && ctx.canWrite && (
                <form action={revokeGuardianLink}>
                  <input type="hidden" name="id" value={g.link_id} />
                  <input type="hidden" name="dogId" value={dog.id} />
                  <ConfirmButton
                    message={`${g.display_name || g.email} 님의 연결을 해제할까요? 즉시 ${dog.name}의 정보를 볼 수 없게 됩니다.`}
                    className={dangerButton}
                  >
                    연결 해제
                  </ConfirmButton>
                </form>
              )}
            </div>
          ))}

          {invitations.length > 0 && (
            <div className="flex flex-col gap-2">
              <p className="text-sm font-medium text-gray-700">초대 대기 중</p>
              {invitations.map((i) => (
                <div key={i.id} className="flex flex-wrap items-center justify-between gap-2 rounded-xl border border-gray-200 p-3">
                  <div>
                    <p>{i.email}</p>
                    <p className="text-sm text-gray-500">
                      {i.relation} · {new Date(i.expires_at).toLocaleDateString("ko-KR")}까지
                    </p>
                  </div>
                  {ctx.canWrite && (
                    <form action={revokeGuardianInvitation}>
                      <input type="hidden" name="id" value={i.id} />
                      <input type="hidden" name="dogId" value={dog.id} />
                      <ConfirmButton message={`${i.email} 초대를 취소할까요?`} className={outlineButton}>
                        취소
                      </ConfirmButton>
                    </form>
                  )}
                </div>
              ))}
            </div>
          )}

          {ctx.canWrite && <GuardianInviteForm dogId={dog.id} />}
        </section>
      )}
    </div>
  );
}

export default function DogPage(props: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ error?: string; saved?: string }>;
}) {
  return (
    <Suspense fallback={<p className="p-6 text-gray-500">불러오는 중…</p>}>
      <DogContent {...props} />
    </Suspense>
  );
}
