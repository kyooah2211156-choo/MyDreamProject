import { Suspense } from "react";
import { createClient } from "@/lib/supabase/server";
import { approveRequest, rejectRequest } from "../actions";
import { dangerButton, inputClass, primaryButton } from "@/lib/ui";

type Req = {
  id: string;
  applicant_name: string | null;
  applicant_email: string | null;
  kindergarten_name: string;
  status: "pending" | "approved" | "rejected";
  reject_reason: string | null;
  created_at: string;
};

const label = { pending: "대기", approved: "승인", rejected: "반려" } as const;

async function RequestsContent({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const { error } = await searchParams;
  const supabase = await createClient();
  const { data } = await supabase
    .from("signup_requests")
    .select("id, applicant_name, applicant_email, kindergarten_name, status, reject_reason, created_at")
    .order("created_at", { ascending: false });
  const rows = (data ?? []) as Req[];
  const pending = rows.filter((r) => r.status === "pending");
  const done = rows.filter((r) => r.status !== "pending");

  return (
    <div className="flex flex-col gap-6">
      <h1 className="text-2xl font-bold">가입 신청</h1>
      {error && <p className="rounded-lg bg-red-50 p-3 text-sm text-red-700">{error}</p>}

      <section className="flex flex-col gap-3">
        <h2 className="text-lg font-semibold">승인 대기 ({pending.length})</h2>
        {pending.length === 0 && <p className="text-gray-500">대기 중인 신청이 없습니다.</p>}
        {pending.map((r) => (
          <div key={r.id} className="flex flex-col gap-3 rounded-xl border border-gray-200 p-4">
            <div>
              <p className="text-lg font-medium">{r.kindergarten_name}</p>
              <p className="text-sm text-gray-600">
                신청자 {r.applicant_name || "(이름 없음)"} · {r.applicant_email}
              </p>
              <p className="text-sm text-gray-500">{new Date(r.created_at).toLocaleString("ko-KR")}</p>
            </div>
            <form action={approveRequest}>
              <input type="hidden" name="id" value={r.id} />
              <button className={`${primaryButton} w-full`}>승인하고 원장으로 등록</button>
            </form>
            <form action={rejectRequest} className="flex flex-col gap-2">
              <input type="hidden" name="id" value={r.id} />
              <input name="reason" placeholder="반려 사유 (선택)" className={inputClass} />
              <button className={dangerButton}>반려</button>
            </form>
          </div>
        ))}
      </section>

      <section className="flex flex-col gap-2">
        <h2 className="text-lg font-semibold">처리 완료</h2>
        {done.length === 0 && <p className="text-gray-500">아직 없습니다.</p>}
        {done.map((r) => (
          <div key={r.id} className="rounded-xl border border-gray-200 p-3">
            <p className="font-medium">
              {r.kindergarten_name} <span className="text-sm text-gray-600">({label[r.status]})</span>
            </p>
            <p className="text-sm text-gray-600">{r.applicant_email}</p>
            {r.reject_reason && <p className="text-sm text-gray-500">사유: {r.reject_reason}</p>}
          </div>
        ))}
      </section>
    </div>
  );
}

export default function RequestsPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  return (
    <Suspense fallback={<p className="p-6 text-gray-500">불러오는 중…</p>}>
      <RequestsContent searchParams={searchParams} />
    </Suspense>
  );
}
