"use server";

import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export async function acceptInvitation(formData: FormData) {
  const raw = formData.get("token");
  const token = typeof raw === "string" ? raw : "";
  if (!/^[0-9a-f]{64}$/.test(token)) redirect("/");

  const supabase = await createClient();
  const { error } = await supabase.rpc("accept_staff_invitation", { p_token: token });
  if (error) {
    const msg = error.message.includes("already belongs")
      ? "이미 소속된 유치원이 있어 수락할 수 없습니다."
      : error.message.includes("email mismatch")
        ? "초대받은 이메일로 로그인해야 합니다."
        : "초대를 수락하지 못했습니다. 만료되었거나 취소된 초대일 수 있습니다.";
    redirect(`/invite/${token}?error=${encodeURIComponent(msg)}`);
  }
  redirect("/");
}
