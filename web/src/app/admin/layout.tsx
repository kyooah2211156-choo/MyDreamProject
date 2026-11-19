import Link from "next/link";
import { Suspense } from "react";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

async function AdminGuard({ children }: { children: React.ReactNode }) {
  const supabase = await createClient();
  const { data: isAdmin } = await supabase.rpc("is_platform_admin");
  if (!isAdmin) redirect("/");

  return (
    <div className="mx-auto min-h-screen w-full max-w-3xl p-4 md:p-8">
      <nav className="mb-6 flex flex-wrap items-center gap-4 border-b border-gray-200 pb-3 text-base">
        <Link href="/" className="text-gray-600">홈</Link>
        <Link href="/admin/requests" className="font-medium">가입 신청</Link>
        <Link href="/admin/kindergartens" className="font-medium">유치원 목록</Link>
      </nav>
      {children}
    </div>
  );
}

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return (
    <Suspense fallback={<p className="p-6 text-gray-500">불러오는 중…</p>}>
      <AdminGuard>{children}</AdminGuard>
    </Suspense>
  );
}
