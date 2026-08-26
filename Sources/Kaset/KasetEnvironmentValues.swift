import SwiftUI

extension EnvironmentValues {
    @Entry var searchFocusTrigger: Binding<Bool> = .constant(false)
}

extension EnvironmentValues {
    @Entry var sidebarNavigationReselectGenerations: Binding<[NavigationItem: Int]> = .constant([:])
}

extension EnvironmentValues {
    @Entry var navigationSelection: Binding<NavigationItem?> = .constant(nil)
}

extension EnvironmentValues {
    @Entry var showCommandBar: Binding<Bool> = .constant(false)
}

extension EnvironmentValues {
    @Entry var showWhatsNew: Binding<Bool> = .constant(false)
}

extension EnvironmentValues {
    @Entry var usesLegacyMacOS15UI = false
}

extension EnvironmentValues {
    @Entry var libraryViewModel: LibraryViewModel?
}

extension EnvironmentValues {
    @Entry var onPlaylistDeleted: (() -> Void)?
}
