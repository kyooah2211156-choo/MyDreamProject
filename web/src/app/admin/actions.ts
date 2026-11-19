"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

const STATUSES = ["active", "suspended", "terminated"] as const;

function str(formData: FormData, key: string) {
  const v = formData.get(key);
  return typeof v === "string" ? v.trim() : "";
}

// 권한 확인은 DB(RLS와 함수)가 한다. 여기서는 결과만 화면에 알린다.
export async function approveRequest(formData: FormData) {
  const supabase = await createClient();
  const { error } = await supabase.rpc("approve_signup_request", {
    p_request_id: str(formData, "id"),
  });
  revalidatePath("/admin/requests");
  if (error) redirect("/admin/requests?error=" + encodeURIComponent("승인하지 못했습니다."));
  redirect("/admin/requests");
}

export async function rejectRequest(formData: FormData) {
  const supabase = await createClient();
  const { error } = await supabase.rpc("reject_signup_request", {
    p_request_id: str(formData, "id"),
    p_reason: str(formData, "reason"),
  });
  revalidatePath("/admin/requests");
  if (error) redirect("/admin/requests?error=" + encodeURIComponent("반려하지 못했습니다."));
  redirect("/admin/requests");
}

export async function setKindergartenStatus(formData: FormData) {
  const status = str(formData, "status");
  if (!(STATUSES as readonly string[]).includes(status)) {
    redirect("/admin/kindergartens?error=" + encodeURIComponent("올바르지 않은 상태입니다."));
  }
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("kindergartens")
    .update({ status })
    .eq("id", str(formData, "id"))
    .select("id");
  revalidatePath("/admin/kindergartens");
  if (error || !data || data.length === 0) {
    redirect("/admin/kindergartens?error=" + encodeURIComponent("상태를 바꾸지 못했습니다."));
  }
  redirect("/admin/kindergartens");
}
