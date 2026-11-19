import { createBrowserClient } from "@supabase/ssr";

// 브라우저에서 Supabase에 접속하는 클라이언트. 공개용(publishable) 키만 사용한다.
export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
  );
}
