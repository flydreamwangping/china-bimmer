import SwiftUI

struct LoginView: View {
    @ObservedObject var model: AppModel
    @State private var phone = ""
    @State private var code = ""

    var body: some View {
        NavigationView {
            Form {
                Section("登录 BMW 互联驾驶") {
                    TextField("8613812345678", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)

                    HStack {
                        TextField("短信验证码", text: $code)
                            .keyboardType(.numberPad)
                        Button("发送验证码") {
                            Task { await model.sendCode(phone: phone) }
                        }
                        .disabled(model.isSendingCode || phone.isEmpty)
                    }

                    if !model.loginStatus.isEmpty {
                        Text(model.loginStatus)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Button {
                        Task { await model.login(phone: phone, code: code) }
                    } label: {
                        HStack {
                            Spacer()
                            if model.isSubmitting { ProgressView() } else { Text("登录") }
                            Spacer()
                        }
                    }
                    .disabled(model.isSubmitting || model.otpID == nil || code.isEmpty)
                }
            }
            .navigationTitle("Bimmer")
        }
    }
}
