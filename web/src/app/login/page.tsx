import { login, signup } from "./actions";

const input =
  "w-full rounded-lg border border-gray-300 px-3 py-3 text-base focus:border-blue-500 focus:outline-none";
const button = "w-full rounded-lg px-4 py-3 text-base font-medium";

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; message?: string }>;
}) {
  const { error, message } = await searchParams;

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-md flex-col justify-center gap-8 p-6">
      <h1 className="text-2xl font-bold">강아지 유치원 관리</h1>

      {error && <p className="rounded-lg bg-red-50 p-3 text-sm text-red-700">{error}</p>}
      {message && <p className="rounded-lg bg-green-50 p-3 text-sm text-green-700">{message}</p>}

      <form action={login} className="flex flex-col gap-3">
        <h2 className="text-lg font-semibold">로그인</h2>
        <input name="email" type="email" placeholder="이메일" required autoComplete="email" className={input} />
        <input name="password" type="password" placeholder="비밀번호" required autoComplete="current-password" className={input} />
        <button className={`${button} bg-blue-600 text-white`}>로그인</button>
      </form>

      <form action={signup} className="flex flex-col gap-3 border-t border-gray-200 pt-6">
        <h2 className="text-lg font-semibold">회원가입</h2>
        <input name="name" type="text" placeholder="이름" required autoComplete="name" className={input} />
        <input name="email" type="email" placeholder="이메일" required autoComplete="email" className={input} />
        <input name="password" type="password" placeholder="비밀번호 (8자 이상)" required minLength={8} autoComplete="new-password" className={input} />
        <button className={`${button} border border-gray-300`}>가입하기</button>
      </form>
    </main>
  );
}
