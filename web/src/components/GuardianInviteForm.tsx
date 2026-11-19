"use client";

import { useActionState } from "react";
import { createGuardianInvitation } from "@/app/dogs/actions";
import type { InviteState } from "@/app/staff/actions";
import { InviteLink } from "@/components/InviteLink";
import { inputClass, primaryButton } from "@/lib/ui";

export function GuardianInviteForm({ dogId }: { dogId: string }) {
  const [state, action, pending] = useActionState<InviteState, FormData>(createGuardianInvitation, {});

  return (
    <div className="flex flex-col gap-3">
      <form action={action} className="flex flex-col gap-3">
        <input type="hidden" name="dogId" value={dogId} />
        <input name="email" type="email" placeholder="보호자 이메일" required className={inputClass} />
        <input name="relation" placeholder="관계 (예: 엄마, 아빠)" required maxLength={20} className={inputClass} />
        <button disabled={pending} className={primaryButton}>
          {pending ? "만드는 중…" : "보호자 초대 링크 만들기"}
        </button>
      </form>
      {state.error && <p className="rounded-lg bg-red-50 p-3 text-sm text-red-700">{state.error}</p>}
      {state.token && <InviteLink path={`/invite/guardian/${state.token}`} />}
    </div>
  );
}
