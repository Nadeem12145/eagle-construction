//
//  Eagle_constructionApp.swift
//  Eagle construction
//
//  Created by Nadeem Abbas on 11/4/26.
//

import SwiftUI
import UIKit

/// UIKit entry point so the root controller can set the status bar per screen
/// (navy headers need light text, white screens dark text) while the app itself stays in light mode.
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = RootHostingController(rootView: ContentView())
        self.window = window
        window.makeKeyAndVisible()
    }
}

final class RootHostingController: UIHostingController<ContentView> {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        StatusBar.isLight ? .lightContent : .darkContent
    }
}
