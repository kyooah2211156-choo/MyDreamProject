import SwiftUI

/// 알림장과 사진첩을 탭으로 묶은 화면.
/// 3단계에서 홈·훈련 탭과 합쳐 4개 탭 구조로 만들 때 재료로 씁니다.
struct NotebookAlbumTabsView: View {
    var body: some View {
        TabView {
            NotebookListView()
                .tabItem { Label("알림장", systemImage: "book.closed.fill") }
            AlbumView()
                .tabItem { Label("사진첩", systemImage: "photo.on.rectangle.angled") }
        }
        .tint(AppTheme.softButtonText)
    }
}

#Preview("원장") {
    NotebookAlbumTabsView()
        .environment(SessionStore(currentUser: SampleData.owner))
        .environment(NotebookStore())
        .environment(HealthRecordStore())
}

#Preview("선생님") {
    NotebookAlbumTabsView()
        .environment(SessionStore(currentUser: SampleData.teacher))
        .environment(NotebookStore())
        .environment(HealthRecordStore())
}

#Preview("보호자 (다크)") {
    NotebookAlbumTabsView()
        .environment(SessionStore(currentUser: SampleData.parent))
        .environment(NotebookStore())
        .environment(HealthRecordStore())
        .preferredColorScheme(.dark)
}
