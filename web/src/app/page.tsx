import { createClient } from "@/lib/supabase/server";
import { logout } from "./login/actions";

export default async function Home() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  const { data: profile } = await supabase
    .from("profiles")
    .select("display_name")
    .maybeSingle();

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-md flex-col justify-center gap-4 p-6">
      <h1 className="text-2xl font-bold">안녕하세요, {profile?.display_name || user?.email}님</h1>
      <p className="text-gray-600">로그인되었습니다. 소속 유치원 기능은 다음 단계에서 추가됩니다.</p>
      <form action={logout}>
        <button className="w-full rounded-lg border border-gray-300 px-4 py-3 text-base">로그아웃</button>
      </form>
    </main>
  );
}
