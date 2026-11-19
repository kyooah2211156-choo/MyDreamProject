import { Suspense } from "react";
import { createClient } from "@/lib/supabase/server";
import { setKindergartenStatus } from "../actions";
import { outlineButton } from "@/lib/ui";

const labels: Record<string, string> = {
  pending: "승인 대기",
  active: "정상",
  suspended: "정지 (읽기 전용)",
  terminated: "해지",
};

async function KindergartensContent({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const { error } = await searchParams;
  const supabase = await createClient();
  const { data } = await supabase
    .from("kindergartens")
    .select("id, name, status, approved_at")
    .order("created_at", { ascending: false });
  const rows = data ?? [];

  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-2xl font-bold">유치원 목록</h1>
      {error && <p className="rounded-lg bg-red-50 p-3 text-sm text-red-700">{error}</p>}
      {rows.length === 0 && <p className="text-gray-500">등록된 유치원이 없습니다.</p>}
      {rows.map((k) => (
        <div key={k.id} className="flex flex-col gap-3 rounded-xl border border-gray-200 p-4">
          <div>
            <p className="text-lg font-medium">{k.name}</p>
            <p className="text-sm text-gray-600">상태: {labels[k.status] ?? k.status}</p>
          </div>
          <form action={setKindergartenStatus} className="flex flex-wrap gap-2">
            <input type="hidden" name="id" value={k.id} />
            {k.status !== "active" && (
              <button name="status" value="active" className={outlineButton}>정상으로</button>
            )}
            {k.status !== "suspended" && (
              <button name="status" value="suspended" className={outlineButton}>정지</button>
            )}
            {k.status !== "terminated" && (
              <button name="status" value="terminated" className={outlineButton}>해지</button>
            )}
          </form>
        </div>
      ))}
    </div>
  );
}

export default function KindergartensPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  return (
    <Suspense fallback={<p className="p-6 text-gray-500">불러오는 중…</p>}>
      <KindergartensContent searchParams={searchParams} />
    </Suspense>
  );
}
