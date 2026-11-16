import Contacts
import ContactsUI
import SwiftUI
import UIKit

/// Rehberden kişi seçme (CNContactPicker). İzin istemez: kullanıcı yalnız seçtiği kişiyi paylaşır.
/// Sayfa (sheet) içinde doğrudan gösterilince boş açılabildiği için görünmez bir denetleyiciden sunulur.
struct RehberSecici: UIViewControllerRepresentable {
    @Binding var acik: Bool
    let secildi: (_ ad: String, _ telefon: String?) -> Void

    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }

    func updateUIViewController(_ vc: UIViewController, context: Context) {
        guard acik, vc.presentedViewController == nil else { return }
        let p = CNContactPickerViewController()
        p.delegate = context.coordinator
        p.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        DispatchQueue.main.async { vc.present(p, animated: true) }
    }

    func makeCoordinator() -> K { K(self) }

    final class K: NSObject, CNContactPickerDelegate {
        let ust: RehberSecici
        init(_ u: RehberSecici) { ust = u }
        func contactPicker(_ picker: CNContactPickerViewController, didSelect kisi: CNContact) {
            let ad = CNContactFormatter.string(from: kisi, style: .fullName) ?? [kisi.givenName, kisi.familyName].joined(separator: " ")
            let tel = kisi.phoneNumbers.first?.value.stringValue
            ust.secildi(ad.trimmingCharacters(in: .whitespaces), tel)
            ust.acik = false
        }
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) { ust.acik = false }
    }
}
