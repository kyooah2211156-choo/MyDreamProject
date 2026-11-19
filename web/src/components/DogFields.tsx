import { inputClass } from "@/lib/ui";

type Dog = {
  name?: string;
  breed?: string | null;
  birth_date?: string | null;
  sex?: string;
  health_notes?: string | null;
};

// 강아지 등록/수정 화면에서 같이 쓰는 입력칸
export function DogFields({ dog, disabled }: { dog?: Dog; disabled?: boolean }) {
  return (
    <>
      <label className="flex flex-col gap-1 text-sm text-gray-700">
        이름
        <input name="name" defaultValue={dog?.name} required maxLength={50} disabled={disabled} className={inputClass} />
      </label>
      <label className="flex flex-col gap-1 text-sm text-gray-700">
        견종
        <input name="breed" defaultValue={dog?.breed ?? ""} maxLength={50} disabled={disabled} className={inputClass} />
      </label>
      <label className="flex flex-col gap-1 text-sm text-gray-700">
        생일
        <input name="birth_date" type="date" defaultValue={dog?.birth_date ?? ""} disabled={disabled} className={inputClass} />
      </label>
      <label className="flex flex-col gap-1 text-sm text-gray-700">
        성별
        <select name="sex" defaultValue={dog?.sex ?? "unknown"} disabled={disabled} className={inputClass}>
          <option value="unknown">모름</option>
          <option value="male">수컷</option>
          <option value="female">암컷</option>
        </select>
      </label>
      <label className="flex flex-col gap-1 text-sm text-gray-700">
        건강·주의사항 (알레르기, 복용 약 등. 연결된 보호자에게도 보입니다)
        <textarea name="health_notes" defaultValue={dog?.health_notes ?? ""} rows={4} maxLength={1000} disabled={disabled} className={inputClass} />
      </label>
    </>
  );
}
