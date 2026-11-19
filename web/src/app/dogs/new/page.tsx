import { Suspense } from "react";
import Link from "next/link";
import { redirect } from "next/navigation";
import { getStaffContext } from "@/lib/staff-context";
import { DogFields } from "@/components/DogFields";
import { createDog } from "../actions";
import { primaryButton } from "@/lib/ui";

async function NewDogContent({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const { error } = await searchParams;
  const ctx = await getStaffContext();
  if (!ctx?.canWrite) redirect("/dogs");

  return (
    <div className="mx-auto flex min-h-screen w-full max-w-md flex-col gap-4 p-4 md:p-8">
      <Link href="/dogs" className="text-gray-600">← 강아지 목록</Link>
      <h1 className="text-2xl font-bold">강아지 등록</h1>
      {error && <p className="rounded-lg bg-red-50 p-3 text-sm text-red-700">{error}</p>}
      <form action={createDog} className="flex flex-col gap-3">
        <input type="hidden" name="kindergartenId" value={ctx.kgId} />
        <DogFields />
        <button className={primaryButton}>등록</button>
      </form>
    </div>
  );
}

export default function NewDogPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  return (
    <Suspense fallback={<p className="p-6 text-gray-500">불러오는 중…</p>}>
      <NewDogContent searchParams={searchParams} />
    </Suspense>
  );
}
