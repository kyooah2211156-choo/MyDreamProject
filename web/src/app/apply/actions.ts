"use server";

import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export async function submitApplication(formData: FormData) {
  const raw = formData.get("kindergartenName");
  const name = typeof raw === "string" ? raw.trim() : "";
  if (name.length < 1 || name.length > 100) {
    redirect("/apply?error=" + encodeURIComponent("유치원 이름은 1~100자로 입력해 주세요."));
  }

  const supabase = await createClient();
  const { error } = await supabase.rpc("submit_signup_request", {
    p_kindergarten_name: name,
  });
  if (error) {
    const msg =
      error.code === "23505"
        ? "이미 승인 대기 중인 신청이 있습니다."
        : error.message.includes("already belongs")
          ? "이미 소속된 유치원이 있습니다."
          : "신청하지 못했습니다. 잠시 후 다시 시도해 주세요.";
    redirect("/apply?error=" + encodeURIComponent(msg));
  }
  redirect("/");
}
