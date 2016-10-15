import UIKit

class ComposePostViewController: UIViewController {
    var postRepository: PostRepository?
    func configure(postRepository: PostRepository) {
        self.postRepository = postRepository
    }

    @IBOutlet var textView: UITextView?
    @IBAction func postAction() {
    }
}
