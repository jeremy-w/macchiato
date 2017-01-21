//: Playground - noun: a place where people can play

import UIKit

// Now I looked at http://www.greghendershott.com/2013/11/markdown-parser-redesign.html
// and decided this was probably a bad idea.
typealias Markdown = String
func ABANDONED_attributedText(fromMarkdown markdown: Markdown) -> NSAttributedString {
    let rendered = NSMutableAttributedString()
    enum State {
        case plainText
        case bulletBoldOrItalic
        case blockQuote
        case hyperlinkAnchor
        case hyperlinkReference
        case hyperlinkURL
    }
    var state = State.plainText
    for char in markdown.characters {
        switch state {
        case .plainText:
            switch char {
            case "*":
                state = .bulletBoldOrItalic

            default:
                rendered.append(NSAttributedString(string: String(describing: char)))
                break
            }

        default:
            break
        }
    }
    return rendered
}

let label = UILabel(frame: CGRect(origin: CGPoint.zero, size: CGSize(width: 400, height: 200)))

label.attributedText = ABANDONED_attributedText(fromMarkdown: "hi *there*")
label.backgroundColor = UIColor.white
label.numberOfLines = 0
label.textAlignment = .center

label