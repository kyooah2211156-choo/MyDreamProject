"use server";

import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

function text(formData: FormData, key: string) {
  const value = formData.get(key);
  return typeof value === "string" ? value.trim() : "";
}

export async function login(formData: FormData) {
  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword({
    email: text(formData, "email"),
    password: text(formData, "password"),
  });
  if (error) {
    redirect("/login?error=" + encodeURIComponent("이메일 또는 비밀번호가 올바르지 않습니다."));
  }
  redirect("/");
}

export async function signup(formData: FormData) {
  const password = text(formData, "password");
  if (password.length < 8) {
    redirect("/login?error=" + encodeURIComponent("비밀번호는 8자 이상이어야 합니다."));
  }
  const supabase = await createClient();
  const { data, error } = await supabase.auth.signUp({
    email: text(formData, "email"),
    password,
    options: { data: { display_name: text(formData, "name") } },
  });
  if (error) {
    redirect("/login?error=" + encodeURIComponent("가입하지 못했습니다. 입력 내용을 확인해 주세요."));
  }
  if (data.session) redirect("/");
  redirect("/login?message=" + encodeURIComponent("가입 확인 메일을 보냈습니다. 메일의 링크를 누른 뒤 로그인해 주세요."));
}

export async function logout() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/login");
}
