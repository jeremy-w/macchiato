import UIKit

/**
 Monitors a UITextView and moves the insertion point in response to gestures.

 - note: This could likely be generalized to work with a UITextInput, and so handle
  UITextfield, too.
 */
final class InsertionPointSwiper {
    fileprivate weak var textView: UITextView?
    init(editableTextView: UITextView) {
        precondition(editableTextView.isEditable,
                     "\(InsertionPointSwiper.self) requires an editable text view, which this is not: \(editableTextView)")

        textView = editableTextView
        installGestures(in: editableTextView)

        assert(!(editableTextView.gestureRecognizers?.isEmpty ?? false),
               "\(editableTextView) should definitely have a gesture recognizer by now, "
            + "but its array is: \(String(describing: editableTextView.gestureRecognizers))")
    }
}

fileprivate extension InsertionPointSwiper {
    func installGestures(in textView: UITextView) {
        for direction: UISwipeGestureRecognizerDirection in [.left, .right] {
            for touches in 1 ... 4 {
                let recognizer = UISwipeGestureRecognizer(target: self, action: #selector(didRecognizeSwipe))
                recognizer.direction = direction
                recognizer.numberOfTouchesRequired = touches
                textView.addGestureRecognizer(recognizer)
            }
        }
    }

    @objc func didRecognizeSwipe(sender: UISwipeGestureRecognizer) {
        print("recognized swipe in \(sender.direction) using \(sender.numberOfTouches) touches")
        guard let textView = textView else { return }
        guard let text = textView.text else { return }

        let motion = characterize(sender)
        let point = textView.selectedRange.location
        let updatedPoint = pointByMoving(by: motion, to: sender.direction, in: text as NSString, at: point)
        guard point != updatedPoint else { return }

        textView.selectedRange = NSRange(location: updatedPoint, length: 0)
    }

    func characterize(_ swipe: UISwipeGestureRecognizer) -> Motion {
        switch swipe.numberOfTouches {
        case 1:
            return .character

        case 2:
            return .word

        case 3:
            return .sentence

        default:
            return .paragraph
        }
    }

    /**
     - important: Notice how this works with NSString and NSRange,
     because that's what UITextView vends its selected range relative to.
     NSString and String count indexes rather differently!
     */
    func pointByMoving(by unit: Motion, to direction: UISwipeGestureRecognizerDirection, in text: NSString, at point: Int) -> Int {
        var updatedPoint = point

        // (@jeremy-w/2016-10-22)FIXME: Need to read out current text direction to properly determine enumeration direction relative to swipe
        let shouldEnumerateBackwards = direction == .left

        var options: NSString.EnumerationOptions = [
            unit.stringEnumerationOption,
            .localized,
            .substringNotRequired,
        ]
        if shouldEnumerateBackwards {
            options.insert(.reverse)
        }

        let headingTowardsEnd = !shouldEnumerateBackwards
        let end = text.length
        text.enumerateSubstrings(
            in: (shouldEnumerateBackwards
                ? NSRange(location: 0, length: point)
                : NSRange(location: point, length: end - point)),
            options: options)
        { (_, substringRange, enclosingRange, shouldStop) in
            updatedPoint = (headingTowardsEnd
                ? NSMaxRange(enclosingRange)
                : enclosingRange.location)
            shouldStop.pointee = true
        }
        return updatedPoint
    }

    enum Motion {
        case character
        case word
        case sentence
        case paragraph

        var stringEnumerationOption: String.EnumerationOptions {
            switch self {
            case .character:
                return .byComposedCharacterSequences

            case .word:
                return .byWords

            case .sentence:
                return .bySentences

            case .paragraph:
                return .byParagraphs
            }
        }
    }
}
