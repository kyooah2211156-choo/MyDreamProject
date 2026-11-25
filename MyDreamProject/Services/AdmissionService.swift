import Foundation

/// 입학 절차 기록을 읽고 쓰는 약속. 서버를 붙일 때 이 약속을 따르는 새 클래스로 바꿔 끼우면 됩니다.
protocol AdmissionService {
    func load() -> [AdmissionRecord]
    func save(_ record: AdmissionRecord)
}

/// 앱을 켜 두는 동안만 기억하는 연습용 저장소
final class FakeAdmissionService: AdmissionService {
    private var records = AdmissionRecord.samples()

    func load() -> [AdmissionRecord] { records }

    func save(_ record: AdmissionRecord) {
        if let index = records.firstIndex(where: { $0.petID == record.petID }) {
            records[index] = record
        } else {
            records.append(record)
        }
    }
}
