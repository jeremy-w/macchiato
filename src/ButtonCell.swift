import UIKit

class ButtonCell: UITableViewCell {
    @nonobjc static let identifier = "ButtonCell"
    @IBOutlet var label: UILabel?

    func configure(text: String) {
        label?.text = text
    }

    override var textLabel: UILabel? {
        return label
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        guard let label = self.label else { return }
        label.textColor = tintColor
    }

    override func tintColorDidChange() {
        super.tintColorDidChange()
        label?.textColor = tintColor
    }

    init() {
        super.init(style: .default, reuseIdentifier: ButtonCell.identifier)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
