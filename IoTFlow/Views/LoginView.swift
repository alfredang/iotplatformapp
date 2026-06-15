import SwiftUI

struct LoginView: View {
    @EnvironmentObject var session: SessionStore

    @State private var isRegister = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.07, blue: 0.15),
                                    Color(red: 0.10, green: 0.13, blue: 0.28)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 52, weight: .semibold))
                            .foregroundStyle(.tint)
                        Text("IoTFlow")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                        Text(isRegister ? "Create your account" : "Sign in to your dashboard")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.top, 60)

                    VStack(spacing: 14) {
                        if isRegister {
                            field("Name", text: $name, icon: "person.fill")
                        }
                        field("Email", text: $email, icon: "envelope.fill",
                              keyboard: .emailAddress)
                        field("Password", text: $password, icon: "lock.fill",
                              secure: true)

                        if let error {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button(action: submit) {
                            HStack {
                                if busy { ProgressView().tint(.white) }
                                Text(isRegister ? "Create account" : "Sign in")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(busy || !isValid)

                        Button {
                            withAnimation { isRegister.toggle(); error = nil }
                        } label: {
                            Text(isRegister ? "Already have an account? Sign in"
                                            : "New here? Create an account")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .padding(20)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 24)

                    Button {
                        session.enterDemo()
                    } label: {
                        Label("Explore demo", systemImage: "play.circle")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    NavigationLink {
                        ServerSettingsView()
                    } label: {
                        Label("Server settings", systemImage: "server.rack")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .overlay(alignment: .topTrailing) { EmptyView() }
        .modifier(EmbeddedNav())
    }

    private var isValid: Bool {
        !email.isEmpty && password.count >= 8 && (!isRegister || !name.isEmpty)
    }

    private func submit() {
        error = nil
        busy = true
        Task {
            do {
                if isRegister {
                    try await session.register(name: name, email: email, password: password)
                } else {
                    try await session.login(email: email, password: password)
                }
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            busy = false
        }
    }

    @ViewBuilder
    private func field(_ placeholder: String, text: Binding<String>, icon: String,
                       keyboard: UIKeyboardType = .default, secure: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 20)
            Group {
                if secure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .foregroundStyle(.white)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Wrap in a navigation stack so the server-settings link works.
private struct EmbeddedNav: ViewModifier {
    func body(content: Content) -> some View {
        NavigationStack { content.toolbar(.hidden, for: .navigationBar) }
    }
}
