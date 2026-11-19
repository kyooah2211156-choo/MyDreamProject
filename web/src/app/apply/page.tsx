import Link from "next/link";
import { Suspense } from "react";
import { submitApplication } from "./actions";
import { inputClass, primaryButton } from "@/lib/ui";

async function ApplyContent({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const { error } = await searchParams;
  return (
    <main className="mx-auto flex min-h-screen w-full max-w-md flex-col justify-center gap-4 p-6">
      <h1 className="text-2xl font-bold">유치원 가입 신청</h1>
      <p className="text-gray-600">
        신청하시면 서비스 운영자가 확인한 뒤 승인합니다. 승인되면 신청하신 분이 원장이 됩니다.
      </p>
      {error && <p className="rounded-lg bg-red-50 p-3 text-sm text-red-700">{error}</p>}
      <form action={submitApplication} className="flex flex-col gap-3">
        <input
          name="kindergartenName"
          type="text"
          placeholder="유치원 이름"
          required
          maxLength={100}
          className={inputClass}
        />
        <button className={primaryButton}>신청하기</button>
      </form>
      <Link href="/" className="text-center text-sm text-gray-600 underline">
        돌아가기
      </Link>
    </main>
  );
}

export default function ApplyPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  return (
    <Suspense fallback={<p className="p-6 text-gray-500">불러오는 중…</p>}>
      <ApplyContent searchParams={searchParams} />
    </Suspense>
  );
}
