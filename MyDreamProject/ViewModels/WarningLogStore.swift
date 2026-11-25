import Foundation
import Observation

/// 보호자 경고 이력 창고. 경고 사유, 자동 기록 시각, 등록한 직원, 이용 중단 사유를 남깁니다.
@Observable
final class WarningLogStore {
    private let service: WarningLogService
    private(set) var records: [WarningRecord] = []

    init(service: WarningLogService = FakeWarningLogService()) {
        self.service = service
        reload()
    }

    private func reload() { records = service.load() }

    /// 보호자 한 명의 이력 (최신순)
    func history(for parentID: String) -> [WarningRecord] {
        records.filter { $0.parentID == parentID }.sorted { $0.date > $1.date }
    }

    /// 가장 최근 이용 중단 사유
    func suspensionRecord(for parentID: String) -> WarningRecord? {
        history(for: parentID).first { $0.kind == .suspended }
    }

    /// 이력 한 줄을 남깁니다. 시각은 지금으로 자동 기록돼요. (화면에서 권한을 먼저 확인한 뒤 호출)
    func log(_ kind: WarningEventKind, parentID: String, reason: String, staffID: String, countAfter: Int) {
        service.add(WarningRecord(id: UUID().uuidString, parentID: parentID, kind: kind,
                                  reason: reason.trimmingCharacters(in: .whitespacesAndNewlines),
                                  date: .now, staffID: staffID, countAfter: countAfter))
        reload()
    }
}
