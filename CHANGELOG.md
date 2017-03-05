# Change Log
Releases of Macchiato are documented below. Dates correspond to when the build
was archived, not necessarily when it became available for download.

## TestFlight Releases
### 1.0 (11) - 2017-03-05
New:

- Keyboard shortcuts for New Post, Send, Attach Image, and Cancel. Hold down Command to see what shortcuts are available at any point. [#76] [#77]

Changed:

- Posts display the image the full width of the screen. [#86]
- Thread views are bootstrapped with posts already on hand. [#92]

Fixed:

- The Interactions stream now tells you who starred or reposted your posts. This is thus the first release where the Interactions display is actually useful. [#58]
- Reposts now display the reposter and date alongside the original post. Post actions are directed at the original post, not the repost-post. [#85]
- Action sheets are now more HIG-compliant. [#90] [#91]


### 1.0 (10) - 2017-02-27
New:

- Upload Image button: Pick an image, and it gets uploaded to the 10C CDN, and corresponding image Markdown appended to the post body. [#12]

Changed:

- Posts display date and username on separate lines. [#74]
- Posts use the full width of the screen for their text block. [#75]
- Starting a new post immediately puts the caret after the first mention. [#24]
- A Post Actions button serves as a more discoverable version of the long-press gesture. [#44]
- Display Markdown rather than raw HTML when post HTML rendering fails [#81]

Fixed:

- Posts are now sorted by publication date, not creation date. Using the wrong date sometimes led to a time range being skipped by Load Older. [#79]
- Logging in should be recognized without a restart. [#57]
- Private posts no longer stay stuck to the top of the post list; they are ignored entirely. [#80]


### 1.0 (9) - 2017-02-17
New:

- "Delete" action appears on own posts. [#69]
- Blockquote now renders as indented, slightly smaller, slightly gray text. [#51]

Changed:

- "New Post" button now says that, rather than "+". [#45]

Fixed:

- Post data received from the API should now pretty much always display something. [#62]


### 1.0 (8) - 2017-02-10
Fixed:

- Give initial stream page a stream and an identity when launched in full split-view glory, so that you can post via it. [#57]
- Log In form no longer stays on screen after log-in succeeds. [#43]
- No longer thinks you're logged in after you've logged out.
- If log-in fails, you'll actually see the error message sent by the 10C API, like "bogus credentials", rather than a uselessly vague "operation failed". [#30]
- Log In button enables as soon as there's text in both the username and password fields. [#49]

Changed:

- New Post button disables rather than vanishing completely when the app doesn't yet know who you are.


### 1.0 (7) - 2017-02-08
Fixed:

- Load images with non-HTTPS source URLs. These were showing up as a blank square beneath the post before. [#61]
- Render "stacked" styles, like bold-italics. Before, only the "topmost" style was applied, so bold-italics would be just italics, and italic-bold would be just bold. [#56]


### 1.0 (6) - 2017-02-05
New:

- URLs linked in a post are listed as buttons below the post text. Tap the button to navigate to the URL within the app.
- Images linked in a post are displayed below any link buttons. They are scaled to fit, so some bits outside the center might have been cropped. Tap the image to see the full image. [#35]
- An "Edit" action appears in the list of post actions for your own posts. This list is the list that is triggered by long-pressing on a post. [#40]
- The background of posts that mention you is now a light blue, to make it easier to skim for mentions. [#41]

Changed:

- Paragraphs now display block-style, with a full blank line between them. [#53]


### 1.0 (5) - 2017-01-30
New:

- Avatars appear alongside post content. [#33]
- Settings has a "Third-Party Components" row. Tap to view licenses for third-party components used by Macchiato. [#52]

Fixed:

- Account info percolates to all stream views, so that you shouldn't see a post action list of just "View in WebView" once you're logged in unless you're really fast or your network is really slow. [#50]


### 1.0 (4) - 2017-01-25
Changed:

- Display rich text rather than raw Markdown.
    - NOTE: Links aren't clickable yet, and images display as their ALT text.
- Omit mentioning yourself when you reply to a post that mentioned you.
    - NOTE: The author of the post you're replying to still gets mentioned, though, so if you reply to your own post, you'll still mention yourself.


### 1.0 (3) - 2017-01-18
Changed:

- Targets iOS 9.3 rather than iOS 10. If you haven't upgraded to 10 yet, you're in luck!


### 1.0 (2) - 2017-01-16
Fixes a crash. Hopefully fixes a login issue related to percent-encoding.

Fixed:

- iPad: Don't crash when showing post actions sheet. [#31]
- Hopefully: Should be able to log in with + in email or password. [#29]
    - Form-urlencoding adds some special "form" sauce atop "url encoding" that I missed.

Changed:

- iPad: Present Settings as a popover.
- Add rudimentary app info in Settings, so you can see what version you're running.


### 1.0 (1) - 2017-01-16
Initial release.

- View Global.
- Log in to view Home and other streams, as well as post using the + button and reply.
- Long-press a post to pull up a menu of actions on that post.
- Swipe left/right while composing a post to move the cursor. Use more fingers to move by bigger units (one by character, two by word, three by sentence).
