"use client";

import { useActionState } from "react";
import { createInvitation, type InviteState } from "@/app/staff/actions";
import { InviteLink } from "@/components/InviteLink";
import { inputClass, primaryButton } from "@/lib/ui";

export function InviteForm({ kindergartenId }: { kindergartenId: string }) {
  const [state, action, pending] = useActionState<InviteState, FormData>(createInvitation, {});

  return (
    <div className="flex flex-col gap-3">
      <form action={action} className="flex flex-col gap-3">
        <input type="hidden" name="kindergartenId" value={kindergartenId} />
        <input name="email" type="email" placeholder="초대할 선생님 이메일" required className={inputClass} />
        <select name="permission" defaultValue="standard" className={inputClass}>
          <option value="view">조회만</option>
          <option value="standard">출결 + 알림장</option>
          <option value="full">전체</option>
        </select>
        <button disabled={pending} className={primaryButton}>
          {pending ? "만드는 중…" : "초대 링크 만들기"}
        </button>
      </form>
      {state.error && <p className="rounded-lg bg-red-50 p-3 text-sm text-red-700">{state.error}</p>}
      {state.token && <InviteLink path={`/invite/${state.token}`} />}
    </div>
  );
}
