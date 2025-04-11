import SwiftUI
import libPhoneNumber

struct Country: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let code: String
    let dialCode: String
    let flag: String
}

let countries: [Country] = [
    Country(name: "United Arab Emirates", code: "AE", dialCode: "+971", flag: "🇦🇪"),
    Country(name: "United States", code: "US", dialCode: "+1", flag: "🇺🇸"),
    Country(name: "United Kingdom", code: "GB", dialCode: "+44", flag: "🇬🇧"),
    Country(name: "Brazil", code: "BR", dialCode: "+55", flag: "🇧🇷"),
    Country(name: "India", code: "IN", dialCode: "+91", flag: "🇮🇳")
]

struct ContentView: View {
    @State private var showPhoneInput = false

    var body: some View {
        if showPhoneInput {
            PhoneInputView()
        } else {
            VStack {
                Spacer()
                Button("Get Started") {
                    showPhoneInput = true
                }
                .font(.title)
                .padding()
                Spacer()
            }
        }
    }
}

struct PhoneInputView: View {
    @State private var selectedCountry: Country = countries.first(where: { $0.code == "AE" })!
    @State private var showCountryPicker = false
    @State private var phoneNumber = ""
    @State private var isValidNumber = false
    @State private var showError = false
    @State private var expectedLength: Int?
    @FocusState private var isPhoneFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Enter your phone number")
                .font(.system(size: 24, weight: .bold))

            Text("Use your phone number to create an account or log in.")
                .font(.system(size: 16))
                .foregroundColor(.gray)

            HStack(spacing: 12) {
                Button(action: {
                    showCountryPicker = true
                }) {
                    HStack {
                        Text(selectedCountry.flag)
                        Text(selectedCountry.dialCode)
                            .font(.system(size: 16))
                            .foregroundColor(.black)
                        Image(systemName: "chevron.down")
                            .foregroundColor(.gray)
                    }
                    .frame(height: 54)
                    .padding(.horizontal, 12)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                }

                ZStack(alignment: .trailing) {
                    TextField("Phone number", text: Binding(
                        get: { phoneNumber },
                        set: { newValue in
                            var normalized = newValue
                            if selectedCountry.code == "AE", normalized.hasPrefix("0") {
                                normalized.removeFirst()
                            }

                            if let max = expectedLength, normalize(newValue).count <= max {
                                phoneNumber = newValue
                            } else if expectedLength == nil {
                                phoneNumber = newValue
                            }

                            let cleaned = normalize(phoneNumber)
                            validatePhoneNumber(trimmed: cleaned)
                        })
                    )
                    .keyboardType(.numberPad)
                    .focused($isPhoneFocused)
                    .frame(height: 54)
                    .padding(.horizontal)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )

                    if !phoneNumber.isEmpty {
                        Button(action: {
                            phoneNumber = ""
                            isValidNumber = false
                            showError = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isPhoneFocused = true
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .padding(.trailing, 12)
                        }
                    }
                }
            }

            if showError {
                Text("Invalid phone number. Check the format.")
                    .foregroundColor(.red)
                    .font(.footnote)
            }

            Spacer()

            Button(action: {
                // handle next step
            }) {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValidNumber ? Color(red: 0.96, green: 0.45, blue: 0.45) : Color(.systemGray4))
                    .cornerRadius(30)
            }
            .disabled(!isValidNumber)
        }
        .padding()
        .background(Color.white.ignoresSafeArea())
        .sheet(isPresented: $showCountryPicker) {
            CountryPickerView(selectedCountry: $selectedCountry)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            updateExpectedLength()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isPhoneFocused = true
            }
        }
        .onChange(of: selectedCountry) { _ in
            updateExpectedLength()
            phoneNumber = ""
            isValidNumber = false
            showError = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isPhoneFocused = true
            }
        }
    }

    func updateExpectedLength() {
        let phoneUtil = NBPhoneNumberUtil.sharedInstance()
        do {
            if let example = try phoneUtil?.getExampleNumber(forType: selectedCountry.code, type: .MOBILE) {
                var formatted = example.nationalNumber.stringValue
                if selectedCountry.code == "AE", formatted.hasPrefix("5") {
                    expectedLength = formatted.count
                } else {
                    expectedLength = formatted.count
                }
            }
        } catch {
            expectedLength = nil
        }
    }

    func normalize(_ number: String) -> String {
        var cleaned = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if selectedCountry.code == "AE", cleaned.hasPrefix("0") {
            cleaned.removeFirst()
        }
        return cleaned
    }

    func checkIfShouldValidate() {
        guard let expectedLength else {
            showError = false
            isValidNumber = false
            return
        }

        let cleanedNumber = normalize(phoneNumber)
        if cleanedNumber.count >= expectedLength {
            validatePhoneNumber(trimmed: cleanedNumber)
        } else {
            isValidNumber = false
            showError = false
        }
    }

    func validatePhoneNumber(trimmed: String? = nil) {
        let phoneUtil = NBPhoneNumberUtil.sharedInstance()

        let normalized = trimmed ?? normalize(phoneNumber)
        let fullNumber = "\(selectedCountry.dialCode)\(normalized)"

        do {
            let parsedNumber = try phoneUtil?.parse(fullNumber, defaultRegion: selectedCountry.code)
            isValidNumber = phoneUtil?.isValidNumber(parsedNumber) ?? false
            showError = !isValidNumber && normalized.count >= (expectedLength ?? 0)
            if isValidNumber {
                isPhoneFocused = false
            }
        } catch {
            isValidNumber = false
            showError = normalized.count >= (expectedLength ?? 0)
        }
        print("Trying: \(fullNumber)")
        print("Valid: \(isValidNumber)")
    }
}

struct CountryPickerView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedCountry: Country

    var body: some View {
        NavigationView {
            List(countries) { country in
                Button(action: {
                    selectedCountry = country
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Text(country.flag)
                        Text(country.name)
                        Spacer()
                        Text(country.dialCode)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
            }
            .listStyle(.plain)
            .navigationTitle("Select Country")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
