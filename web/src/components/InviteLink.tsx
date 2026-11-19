"use client";

import { useState } from "react";
import { outlineButton } from "@/lib/ui";

// 초대 링크를 한 번만 보여 주고 복사할 수 있게 한다.
export function InviteLink({ path }: { path: string }) {
  const [copied, setCopied] = useState(false);
  const link = `${window.location.origin}${path}`;
  return (
    <div className="flex flex-col gap-2 rounded-lg bg-green-50 p-3 text-sm">
      <p className="font-medium text-green-800">
        초대 링크가 만들어졌습니다. 이 링크는 지금만 볼 수 있으니 복사해서 전달해 주세요.
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
  );
}
