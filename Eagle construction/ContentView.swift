//
//  ContentView.swift
//  Eagle construction
//
//  Created by Nadeem Abbas on 11/4/26.
//

import SwiftUI

struct ContentView: View {
    @State private var session = Session()
    @State private var toaster = Toaster()

    var body: some View {
        RootView()
            .modifier(ToastOverlay())
            .environment(session)
            .environment(toaster)
    }
}

/// Splash while the saved login is checked, then sign-in, the next onboarding step, or the Client / Worker app.
struct RootView: View {
    @Environment(Session.self) private var session
    @State private var splashDone = false

    var body: some View {
        Group {
            if session.isRestoring || !splashDone {
                SplashScreen()
            } else if let me = session.me {
                if me.nextStep == "home" {
                    AppStack { MainView() }.id("main-\(me.id)-\(session.resetCount)")
                } else {
                    AppStack { OnboardingStepView(step: me.nextStep) }.id("step-\(me.nextStep)-\(session.resetCount)")
                }
            } else if let error = session.restoreError {
                RestoreFailedView(message: error)
            } else {
                AppStack { SignupRoleScreen() }.id("signed-out-\(session.resetCount)")
            }
        }
        .task {
            async let minimumSplash: Void = Task.sleep(for: .seconds(1.2))
            await session.restore()
            try? await minimumSplash
            splashDone = true
        }
    }
}

private struct RestoreFailedView: View {
    let message: String
    @Environment(Session.self) private var session

    var body: some View {
        VStack(spacing: 16) {
            Image("logo_full").resizable().scaledToFit().frame(width: 200)
            Text(message).type(15, .regular, Palette.text2).multilineTextAlignment(.center).padding(.horizontal, 30)
            AppButton(title: "Try Again", height: 48) { Task { await session.restore() } }.frame(width: 180)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
        .darkStatusBar()
    }
}
