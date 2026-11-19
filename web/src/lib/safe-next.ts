// 로그인 후 돌아갈 주소. 이 사이트 안의 경로만 허용한다(외부 주소로 보내는 공격 방지).
export function safeNext(value: unknown): string {
  if (typeof value !== "string") return "/";
  if (!value.startsWith("/") || value.startsWith("//") || value.includes("\\")) return "/";
  return value;
}
