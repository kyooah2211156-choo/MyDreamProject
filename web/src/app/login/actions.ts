"use server";

import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { safeNext } from "@/lib/safe-next";

function text(formData: FormData, key: string) {
  const value = formData.get(key);
  return typeof value === "string" ? value.trim() : "";
}

function withNext(path: string, formData: FormData) {
  const next = safeNext(formData.get("next"));
  return next === "/" ? path : `${path}&next=${encodeURIComponent(next)}`;
}

export async function login(formData: FormData) {
  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword({
    email: text(formData, "email"),
    password: text(formData, "password"),
  });
  if (error) {
    redirect(withNext("/login?error=" + encodeURIComponent("이메일 또는 비밀번호가 올바르지 않습니다."), formData));
  }
  redirect(safeNext(formData.get("next")));
}

export async function signup(formData: FormData) {
  const password = text(formData, "password");
  if (password.length < 8) {
    redirect(withNext("/login?error=" + encodeURIComponent("비밀번호는 8자 이상이어야 합니다."), formData));
  }
  const supabase = await createClient();
  const { data, error } = await supabase.auth.signUp({
    email: text(formData, "email"),
    password,
    options: { data: { display_name: text(formData, "name") } },
  });
  if (error) {
    console.error("signup failed:", error.code, error.message);
    const reasons: Record<string, string> = {
      user_already_exists: "이미 가입된 이메일입니다. 로그인해 주세요.",
      email_exists: "이미 가입된 이메일입니다. 로그인해 주세요.",
      email_address_invalid: "사용할 수 없는 이메일 주소입니다. 실제 사용하는 이메일로 입력해 주세요.",
      weak_password: "비밀번호가 너무 쉽습니다. 더 길고 복잡하게 만들어 주세요.",
      over_email_send_rate_limit: "인증 메일을 너무 많이 보냈습니다. 잠시 뒤(약 1시간) 다시 시도하거나 메일 인증 설정을 꺼 주세요.",
      over_request_rate_limit: "요청이 너무 많습니다. 잠시 뒤 다시 시도해 주세요.",
      signup_disabled: "현재 가입이 막혀 있습니다. (Supabase 설정 확인 필요)",
      unexpected_failure: "서버 저장 중 오류가 났습니다. (DB 설정 확인 필요)",
    };
    const reason = (error.code && reasons[error.code]) || "가입하지 못했습니다. 입력 내용을 확인해 주세요.";
    redirect(withNext("/login?error=" + encodeURIComponent(`${reason} [${error.code ?? error.status ?? "unknown"}]`), formData));
  }
  if (data.session) redirect(safeNext(formData.get("next")));
  redirect("/login?message=" + encodeURIComponent("가입 확인 메일을 보냈습니다. 메일의 링크를 누른 뒤 로그인해 주세요."));
}

export async function logout() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/login");
}
