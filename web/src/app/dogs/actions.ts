"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import type { InviteState } from "@/app/staff/actions";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

function str(formData: FormData, key: string) {
  const v = formData.get(key);
  return typeof v === "string" ? v.trim() : "";
}

function dogFields(formData: FormData): { fields?: Record<string, string | null>; error?: string } {
  const name = str(formData, "name");
  const breed = str(formData, "breed");
  const birth = str(formData, "birth_date");
  const sex = str(formData, "sex") || "unknown";
  const notes = str(formData, "health_notes");
  if (name.length < 1 || name.length > 50) return { error: "이름은 1~50자로 입력해 주세요." };
  if (breed.length > 50) return { error: "견종은 50자 이내로 입력해 주세요." };
  if (!["male", "female", "unknown"].includes(sex)) return { error: "성별 값이 올바르지 않습니다." };
  if (birth && (!/^\d{4}-\d{2}-\d{2}$/.test(birth) || birth > new Date().toISOString().slice(0, 10))) {
    return { error: "생일은 오늘 이전의 날짜로 입력해 주세요." };
  }
  if (notes.length > 1000) return { error: "건강·주의사항은 1000자 이내로 입력해 주세요." };
  return { fields: { name, breed: breed || null, birth_date: birth || null, sex, health_notes: notes || null } };
}

export async function createDog(formData: FormData) {
  const { fields, error: invalid } = dogFields(formData);
  if (!fields) redirect("/dogs/new?error=" + encodeURIComponent(invalid!));
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("dogs")
    .insert({ ...fields, kindergarten_id: str(formData, "kindergartenId") })
    .select("id")
    .single();
  if (error || !data) {
    const msg = error?.code === "42501"
      ? "등록할 수 없습니다. (권한이 없거나 이용이 정지된 유치원)"
      : "등록하지 못했습니다.";
    redirect("/dogs/new?error=" + encodeURIComponent(msg));
  }
  revalidatePath("/dogs");
  redirect(`/dogs/${data.id}`);
}

export async function updateDog(formData: FormData) {
  const id = str(formData, "id");
  if (!UUID.test(id)) redirect("/dogs");
  const { fields, error: invalid } = dogFields(formData);
  if (!fields) redirect(`/dogs/${id}?error=` + encodeURIComponent(invalid!));
  const supabase = await createClient();
  const { data, error } = await supabase.from("dogs").update(fields).eq("id", id).select("id");
  revalidatePath(`/dogs/${id}`);
  if (error || !data?.length) redirect(`/dogs/${id}?error=` + encodeURIComponent("수정하지 못했습니다. 권한을 확인해 주세요."));
  redirect(`/dogs/${id}?saved=1`);
}

export async function createGuardianInvitation(_prev: InviteState, formData: FormData): Promise<InviteState> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("create_guardian_invitation", {
    p_dog: str(formData, "dogId"),
    p_email: str(formData, "email"),
    p_relation: str(formData, "relation"),
  });
  if (error) {
    if (error.code === "23505") return { error: "이미 초대 중인 이메일입니다. 기존 초대를 취소한 뒤 다시 만들어 주세요." };
    if (error.message.includes("already linked")) return { error: "이미 연결된 보호자입니다." };
    if (error.code === "22023") return { error: "이메일 형식과 관계(1~20자)를 확인해 주세요." };
    if (error.code === "42501") return { error: "초대할 수 없는 상태입니다. (권한이 없거나 이용이 정지된 유치원)" };
    return { error: "초대를 만들지 못했습니다." };
  }
  revalidatePath(`/dogs/${str(formData, "dogId")}`);
  return { token: data as string };
}

export async function revokeGuardianInvitation(formData: FormData) {
  const dogId = str(formData, "dogId");
  if (!UUID.test(dogId)) redirect("/dogs");
  const supabase = await createClient();
  const { error } = await supabase.rpc("revoke_guardian_invitation", { p_id: str(formData, "id") });
  revalidatePath(`/dogs/${dogId}`);
  if (error) redirect(`/dogs/${dogId}?error=` + encodeURIComponent("초대를 취소하지 못했습니다."));
  redirect(`/dogs/${dogId}`);
}

export async function revokeGuardianLink(formData: FormData) {
  const dogId = str(formData, "dogId");
  if (!UUID.test(dogId)) redirect("/dogs");
  const supabase = await createClient();
  const { error } = await supabase.rpc("revoke_guardian_link", { p_link_id: str(formData, "id") });
  revalidatePath(`/dogs/${dogId}`);
  if (error) redirect(`/dogs/${dogId}?error=` + encodeURIComponent("연결을 해제하지 못했습니다."));
  redirect(`/dogs/${dogId}`);
}
