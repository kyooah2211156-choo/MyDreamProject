import { Suspense } from "react";
import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getStaffContext } from "@/lib/staff-context";
import { primaryButton } from "@/lib/ui";

async function DogsContent() {
  const ctx = await getStaffContext();
  if (!ctx) redirect("/");
  const supabase = await createClient();
  const { data } = await supabase
    .from("dogs")
    .select("id, name, breed")
    .eq("kindergarten_id", ctx.kgId)
    .order("name");
  const dogs = data ?? [];

  return (
    <div className="mx-auto flex min-h-screen w-full max-w-2xl flex-col gap-4 p-4 md:p-8">
      <nav className="flex items-center gap-4 border-b border-gray-200 pb-3">
        <Link href="/" className="text-gray-600">홈</Link>
        <span className="font-medium">강아지 · {ctx.kgName}</span>
      </nav>
      {ctx.canWrite && (
        <Link href="/dogs/new" className={`${primaryButton} text-center`}>강아지 등록</Link>
      )}
      {dogs.length === 0 && <p className="text-gray-500">등록된 강아지가 없습니다.</p>}
      {dogs.map((d) => (
        <Link key={d.id} href={`/dogs/${d.id}`} className="rounded-xl border border-gray-200 p-4">
          <p className="text-lg font-medium">{d.name}</p>
          <p className="text-sm text-gray-600">{d.breed || "견종 미입력"}</p>
        </Link>
      ))}
    </div>
  );
}

export default function DogsPage() {
  return (
    <Suspense fallback={<p className="p-6 text-gray-500">불러오는 중…</p>}>
      <DogsContent />
    </Suspense>
  );
}
