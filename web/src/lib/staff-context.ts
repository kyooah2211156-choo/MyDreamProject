import { createClient } from "@/lib/supabase/server";

export type StaffContext = {
  userId: string;
  kgId: string;
  kgName: string;
  kgStatus: string;
  role: "director" | "teacher";
  permission: string;
  canManage: boolean; // 원장 또는 전체 권한: 강아지 등록·수정, 보호자 연결 가능(정지 중에는 읽기만)
  canWrite: boolean; // canManage이고 유치원이 정상 상태
};

// 로그인한 사용자의 재직 정보. 재직 중인 유치원이 없으면 null.
export async function getStaffContext(): Promise<StaffContext | null> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const { data } = await supabase
    .from("staff_memberships")
    .select("role, permission, kindergarten_id, kindergartens(name, status)")
    .eq("user_id", user.id)
    .eq("status", "active")
    .limit(1);
  const row = data?.[0] as unknown as
    | {
        role: "director" | "teacher";
        permission: string;
        kindergarten_id: string;
        kindergartens: { name: string; status: string } | null;
      }
    | undefined;
  if (!row?.kindergartens) return null;

  const canManage = row.role === "director" || row.permission === "full";
  return {
    userId: user.id,
    kgId: row.kindergarten_id,
    kgName: row.kindergartens.name,
    kgStatus: row.kindergartens.status,
    role: row.role,
    permission: row.permission,
    canManage,
    canWrite: canManage && row.kindergartens.status === "active",
  };
}
