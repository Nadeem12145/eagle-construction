import SwiftUI
import UIKit

/// Screens draw their own headers with the system bar hidden, which would otherwise disable swipe-back.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}

/// One pushed screen. Destinations are type-erased views so any screen can open any other.
nonisolated struct Route: Hashable {
    let id = UUID()
    let view: AnyView

    static func == (lhs: Route, rhs: Route) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

@Observable
final class Navigator {
    var path: [Route] = []

    func push<V: View>(_ view: V) {
        path.append(Route(view: AnyView(view)))
    }

    func pop() {
        if !path.isEmpty { path.removeLast() }
    }

    func popToRoot() {
        path.removeAll()
    }
}

/// NavigationStack with hidden system bars; every screen draws its own header.
struct AppStack<Root: View>: View {
    @State private var nav = Navigator()
    @ViewBuilder var root: Root

    var body: some View {
        NavigationStack(path: $nav.path) {
            root
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: Route.self) { route in
                    route.view.toolbar(.hidden, for: .navigationBar)
                }
        }
        .environment(nav)
    }
}
