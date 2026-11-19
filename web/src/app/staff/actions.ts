"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

const PERMISSIONS = ["view", "standard", "full"];

function str(formData: FormData, key: string) {
  const v = formData.get(key);
  return typeof v === "string" ? v.trim() : "";
}

export type InviteState = { error?: string; token?: string };

// 권한 확인은 DB가 한다. 여기서는 결과를 알기 쉬운 문장으로 바꿔 보여 준다.
export async function createInvitation(_prev: InviteState, formData: FormData): Promise<InviteState> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("create_staff_invitation", {
    p_kg: str(formData, "kindergartenId"),
    p_email: str(formData, "email"),
    p_permission: str(formData, "permission"),
  });
  if (error) {
    if (error.code === "23505") return { error: "이미 초대 중인 이메일입니다. 기존 초대를 취소한 뒤 다시 만들어 주세요." };
    if (error.message.includes("already staff")) return { error: "이미 재직 중인 직원입니다." };
    if (error.code === "22023") return { error: "이메일 형식과 권한을 확인해 주세요." };
    if (error.code === "42501") return { error: "초대할 수 없는 상태입니다. (권한이 없거나 이용이 정지된 유치원)" };
    return { error: "초대를 만들지 못했습니다." };
  }
  revalidatePath("/staff");
  return { token: data as string };
}

export async function revokeInvitation(formData: FormData) {
  const supabase = await createClient();
  const { error } = await supabase.rpc("revoke_staff_invitation", { p_id: str(formData, "id") });
  revalidatePath("/staff");
  if (error) redirect("/staff?error=" + encodeURIComponent("초대를 취소하지 못했습니다."));
  redirect("/staff");
}

export async function updatePermission(formData: FormData) {
  const permission = str(formData, "permission");
  if (!PERMISSIONS.includes(permission)) redirect("/staff?error=" + encodeURIComponent("올바르지 않은 권한입니다."));
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("staff_memberships")
    .update({ permission })
    .eq("id", str(formData, "id"))
    .select("id");
  revalidatePath("/staff");
  if (error || !data?.length) redirect("/staff?error=" + encodeURIComponent("권한을 바꾸지 못했습니다."));
  redirect("/staff");
}

export async function leaveStaff(formData: FormData) {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("staff_memberships")
    .update({ status: "left" })
    .eq("id", str(formData, "id"))
    .select("id");
  revalidatePath("/staff");
  if (error || !data?.length) redirect("/staff?error=" + encodeURIComponent("퇴사 처리하지 못했습니다."));
  redirect("/staff");
}
