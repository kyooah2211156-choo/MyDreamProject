import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

// 서버(페이지, 서버 액션)에서 쓰는 Supabase 클라이언트. 로그인 정보는 쿠키에서 읽는다.
export async function createClient() {
  const cookieStore = await cookies();
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    {
      cookies: {
        getAll: () => cookieStore.getAll(),
        setAll: (items) => {
          try {
            items.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options),
            );
          } catch {
            // 서버 컴포넌트에서는 쿠키를 쓸 수 없다. proxy가 갱신을 맡으므로 무시해도 된다.
          }
        },
      },
    },
  );
}
