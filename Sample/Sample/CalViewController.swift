
import DynamicKit
import UIKit

class CalViewController: UIViewController, UITextFieldDelegate {
    @IBOutlet internal var inputField: UITextField!
    @IBOutlet internal var outputView: UITextView!

    internal var output = NSMutableAttributedString()

    internal func addOutput(_ string: String, color: UIColor) {
        let text = NSAttributedString(string: string + "\n\n", attributes: [
            NSAttributedStringKey.foregroundColor: color,
            NSAttributedStringKey.font: outputView.font!,
        ])

        output.replaceCharacters(in: NSMakeRange(0, 0), with: text)
        outputView.attributedText = output
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        inputField.text = "1 + 2 * (3 + 4) / 2"
        output.append(outputView.attributedText)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let text = textField.text, !text.isEmpty {
            do {
                let result = try Expression(text).evaluate()
                addOutput(String(format: "%@ = %g", text, result), color: .black)
            } catch {
                addOutput("\(error)", color: .red)
            }
        }
        return false
    }
}
