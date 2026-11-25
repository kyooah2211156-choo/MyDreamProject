import Foundation
import Observation

/// 선생님 첫 화면의 데이터와 동작을 담당 (지금은 가상 데이터만 사용)
@Observable
final class TeacherHomeViewModel {
    private(set) var kindergartenName: String
    private let nameStore: KindergartenNameStoring
    static let maxNameLength = 20
    private(set) var dogs: [Dog]
    /// 등원 상태가 어느 날의 것인지. 날짜가 바뀌면 모두 '등원 대기'로 돌려요.
    private(set) var attendanceDay: Date
    /// 등원·하원을 눌렀을 때 알려 주는 곳. 출석 기록, 보호자 알림, 이용권 차감이 여기에 연결돼요.
    var onCheckIn: ((Dog) -> Void)?
    var onCheckOut: ((Dog) -> Void)?

    /// 저장된 유치원 이름이 있으면 그것을, 없으면 `kindergartenName`을 기본값으로 씁니다.
    init(kindergartenName: String, dogs: [Dog],
         nameStore: KindergartenNameStoring = UserDefaultsKindergartenNameStore()) {
        self.nameStore = nameStore
        self.kindergartenName = nameStore.load() ?? kindergartenName
        self.dogs = dogs
        self.attendanceDay = Calendar.current.startOfDay(for: .now)
    }

    /// 유치원 이름 수정. 앞뒤 공백은 지우고, 비어 있으면 무시하며, 20자까지만 저장합니다.
    func renameKindergarten(to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let name = String(trimmed.prefix(Self.maxNameLength))
        kindergartenName = name
        nameStore.save(name)
    }

    /// 승인된 전체 강아지 수 (오늘 올 수 있는 아이들)
    var scheduledCount: Int { dogs.count }

    /// 지금 등원해 있는 강아지 수
    var arrivedCount: Int { presentDogs.count }

    var expectedDogs: [Dog] { dogs.filter { $0.status == .expected } }
    var presentDogs: [Dog] { dogs.filter { $0.status == .present } }

    /// 오늘 등원해 있는 반려견 id. 알림장·건강 기록·훈련 화면이 이 아이들만 보여줄 때 씁니다.
    var presentPetIDs: Set<String> { Set(presentDogs.compactMap(\.petID)) }

    /// 날짜가 바뀌었으면 모든 강아지를 '등원 대기'로 되돌립니다.
    /// 매일 오는 아이가 다르기 때문에, 어제 등원 상태를 오늘로 가져오지 않아요.
    func startNewDayIfNeeded(now: Date = .now) {
        let calendar = Calendar.current
        guard !calendar.isDate(attendanceDay, inSameDayAs: now) else { return }
        attendanceDay = calendar.startOfDay(for: now)
        for index in dogs.indices {
            dogs[index].status = .expected
            dogs[index].checkInTime = nil
        }
    }

    /// 승인된 반려견과 등원 목록을 맞춥니다.
    /// 새로 승인된 반려견은 '등원 예정'으로 추가하고, 이름·견종은 최신으로 고칩니다.
    func sync(with pets: [Pet]) {
        for pet in pets where pet.isApproved {
            if let index = dogs.firstIndex(where: { $0.petID == pet.id }) {
                dogs[index].name = pet.name
                dogs[index].breed = pet.breed
            } else {
                dogs.append(Dog(name: pet.name, breed: pet.breed, petID: pet.id))
            }
        }
    }

    func checkIn(_ dog: Dog) {
        guard let i = dogs.firstIndex(where: { $0.id == dog.id }),
              dogs[i].status == .expected else { return }
        dogs[i].status = .present
        // 하원을 잘못 눌러 되돌린 경우에는 처음 등원한 시각을 그대로 둡니다.
        dogs[i].checkInTime = dogs[i].checkInTime ?? .now
        onCheckIn?(dogs[i])
    }

    /// 하원하면 사라지지 않고 '등원 대기'로 내려가요. (실수로 눌러도 다시 등원시킬 수 있어요)
    func checkOut(_ dog: Dog) {
        guard let i = dogs.firstIndex(where: { $0.id == dog.id }),
              dogs[i].status == .present else { return }
        dogs[i].status = .expected
        onCheckOut?(dogs[i])
    }
}

extension TeacherHomeViewModel {
    /// 원장·선생님에게는 오늘 등원해 있는 반려견만 남기고, 보호자 목록은 그대로 둡니다.
    /// 등원 정보(`attendance`)가 없으면 거르지 않아요.
    static func todaysPets(_ pets: [Pet], for user: User, attendance: TeacherHomeViewModel?) -> [Pet] {
        guard user.role == .owner || user.role == .teacher, let attendance else { return pets }
        let present = attendance.presentPetIDs
        return pets.filter { present.contains($0.id) }
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
