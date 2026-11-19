"use client";

import { useActionState, useState } from "react";
import { createInvitation, type InviteState } from "@/app/staff/actions";
import { inputClass, outlineButton, primaryButton } from "@/lib/ui";

export function InviteForm({ kindergartenId }: { kindergartenId: string }) {
  const [state, action, pending] = useActionState<InviteState, FormData>(createInvitation, {});
  const [copied, setCopied] = useState(false);
  const link = state.token ? `${window.location.origin}/invite/${state.token}` : "";

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

      {link && (
        <div className="flex flex-col gap-2 rounded-lg bg-green-50 p-3 text-sm">
          <p className="font-medium text-green-800">
            초대 링크가 만들어졌습니다. 이 링크는 지금만 볼 수 있으니 복사해서 선생님께 전달해 주세요.
            (7일 안에, 초대한 이메일로 로그인해야 사용할 수 있습니다)
          </p>
          <p className="break-all rounded bg-white p-2 text-gray-800">{link}</p>
          <button
            type="button"
            className={outlineButton}
            onClick={async () => {
              await navigator.clipboard.writeText(link);
              setCopied(true);
            }}
          >
            {copied ? "복사됨" : "링크 복사"}
          </button>
        </div>
      )}
    </div>
  );
}
