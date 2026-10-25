import SwiftUI

struct LoginView: View {
    @ObservedObject var model: AppModel
    @State private var phone = ""
    @State private var code = ""

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Theme.amber)
                    Text("Bimmer")
                        .font(.title)
                        .bold()
                        .foregroundColor(Theme.ink)
                    Text("BMW 互联驾驶")
                        .font(.subheadline)
                        .foregroundColor(Theme.inkFaint)
                }

                VStack(spacing: 12) {
                    TextField("86 + 手机号", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .padding(12)
                        .background(Theme.surface2)
                        .cornerRadius(Theme.tileRadius)
                        .foregroundColor(Theme.ink)

                    HStack(spacing: 8) {
                        TextField("短信验证码", text: $code)
                            .keyboardType(.numberPad)
                            .padding(12)
                            .background(Theme.surface2)
                            .cornerRadius(Theme.tileRadius)
                            .foregroundColor(Theme.ink)

                        Button("发送验证码") {
                            Task { await model.sendCode(phone: phone) }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(Theme.surface2)
                        .cornerRadius(Theme.tileRadius)
                        .foregroundColor(Theme.amber)
                        .disabled(model.isSendingCode || phone.isEmpty)
                    }

                    if !model.loginStatus.isEmpty {
                        Text(model.loginStatus)
                            .font(.footnote)
                            .foregroundColor(Theme.inkDim)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task { await model.login(phone: phone, code: code) }
                    } label: {
                        HStack {
                            Spacer()
                            if model.isSubmitting {
                                ProgressView().tint(Theme.bg)
                            } else {
                                Text("登录").bold()
                            }
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .background(Theme.amber)
                        .cornerRadius(Theme.cardRadius)
                        .foregroundColor(Theme.bg)
                    }
                    .disabled(model.isSubmitting || model.otpID == nil || code.isEmpty)
                }
            }
            .padding(Theme.pageMargin)
        }
        .preferredColorScheme(.dark)
    }
}
