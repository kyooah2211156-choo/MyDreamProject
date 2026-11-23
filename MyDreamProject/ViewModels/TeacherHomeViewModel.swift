import Foundation
import Observation

/// 선생님 첫 화면의 데이터와 동작을 담당 (지금은 가상 데이터만 사용)
@Observable
final class TeacherHomeViewModel {
    private(set) var kindergartenName: String
    private let nameStore: KindergartenNameStoring
    static let maxNameLength = 20
    private(set) var dogs: [Dog]
    /// 알림장 작성 버튼을 누른 강아지 (다음 단계에서 작성 화면으로 연결 예정)
    var dogForNotebook: Dog?

    /// 저장된 유치원 이름이 있으면 그것을, 없으면 `kindergartenName`을 기본값으로 씁니다.
    init(kindergartenName: String, dogs: [Dog],
         nameStore: KindergartenNameStoring = UserDefaultsKindergartenNameStore()) {
        self.nameStore = nameStore
        self.kindergartenName = nameStore.load() ?? kindergartenName
        self.dogs = dogs
    }

    /// 유치원 이름 수정. 앞뒤 공백은 지우고, 비어 있으면 무시하며, 20자까지만 저장합니다.
    func renameKindergarten(to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let name = String(trimmed.prefix(Self.maxNameLength))
        kindergartenName = name
        nameStore.save(name)
    }

    /// 오늘 등원 예정 전체 수 (아직 안 온 아이 + 온 아이 + 이미 간 아이)
    var scheduledCount: Int { dogs.count }

    /// 이미 등원한 강아지 수 (현재 있는 아이 + 이미 하원한 아이)
    var arrivedCount: Int { dogs.filter { $0.status != .expected }.count }

    var expectedDogs: [Dog] { dogs.filter { $0.status == .expected } }
    var presentDogs: [Dog] { dogs.filter { $0.status == .present } }

    func checkIn(_ dog: Dog) {
        guard let i = dogs.firstIndex(where: { $0.id == dog.id }),
              dogs[i].status == .expected else { return }
        dogs[i].status = .present
        dogs[i].checkInTime = .now
    }

    func checkOut(_ dog: Dog) {
        guard let i = dogs.firstIndex(where: { $0.id == dog.id }),
              dogs[i].status == .present else { return }
        dogs[i].status = .departed
    }
}

extension TeacherHomeViewModel {
    /// 실제 앱에서 쓰는 버전 (유치원 이름이 기기에 저장됩니다)
    static var live: TeacherHomeViewModel {
        TeacherHomeViewModel(kindergartenName: "댕댕이 유치원", dogs: Dog.samples)
    }

    /// 미리보기용 (저장하지 않음)
    static var sample: TeacherHomeViewModel {
        TeacherHomeViewModel(kindergartenName: "댕댕이 유치원", dogs: Dog.samples,
                             nameStore: InMemoryKindergartenNameStore())
    }
}
