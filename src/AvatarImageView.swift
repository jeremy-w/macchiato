import UIKit
import Kingfisher

protocol AvatarImageViewDelegate: class {
    func tapped(avatarImageView: AvatarImageView)
    func longPressed(avatarImageView: AvatarImageView)
}

class AvatarImageView: UIImageView {
    private(set) var account: Account?
    private(set) weak var delegate: AvatarImageViewDelegate?
    func display(account: Account?, delegate: AvatarImageViewDelegate?) {
        self.account = account
        self.delegate = delegate
        kf.setImage(with: account?.avatarURL ?? Account.defaultAvatarURL)

        configureRecognizers()
        roundCorners(of: self)
    }

    fileprivate var tapper: UITapGestureRecognizer?
    fileprivate var presser: UILongPressGestureRecognizer?
}

fileprivate extension AvatarImageView {
    func configureRecognizers() {
        guard delegate != nil else {
            tapper.map { removeGestureRecognizer($0); self.tapper = nil }
            presser.map { removeGestureRecognizer($0); self.presser = nil }
            return
        }

        if tapper == nil {
            let tapper = UITapGestureRecognizer(target: self, action: #selector(tapped))
            addGestureRecognizer(tapper)
            self.tapper = tapper
        }

        if presser == nil {
            let presser = UILongPressGestureRecognizer(target: self, action: #selector(pressed))
            self.presser = presser
        }
    }

    @IBAction func tapped() {
        delegate?.tapped(avatarImageView: self)
    }

    @IBAction func pressed() {
        delegate?.longPressed(avatarImageView: self)
    }
}
