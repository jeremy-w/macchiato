# Change Log
Releases of Macchiato are documented below. Dates correspond to when the build
was archived, not necessarily when it became available for download.

## TestFlight Releases
### 2.0 (28) - 2020-09-??
XXX

### 2.0 (27) - 2020-06-06
No changes.

### 2.0 (26) - 2020-03-10
New:

- Quote posts show any title, author, and link as part of the post title.

Fixed:

- Pin colors are no longer mis-reported.
- The background of the login page is no longer transparent. Thanks, @matigo!

### 2.0 (25) - 2019-10-21
New:

- Macchiato supports Dark Mode under iOS 13.
- "Share" post action shares the post's canonical URL.

Changed:

- The "Pinned" and "Starred" streams are no longer separate.
- The "Interactions" stream is now named "Stars & Pins".

Fixed:

- Pinning works again.
- All posts mentioning you are highlighted, not only those in threads.
- "More Posts" button at end of stream loads more posts.
- "View in WebView" works. It shows the dedicated page for that post.

Removed:

- The "Starters" stream no longer exists in 10Centuries v5 and has been removed.
- The "Interactions" stream that showed others' interactions with your posts is no longer provided by 10Centuries v5. (The interactions you saw here with v2.0 (23) and (24) were your own interactions with others' posts.)


### 2.0 (24) - 2019-07-15
Fixed:

- No longer mentions self when replying a post. Thanks for the nudge, @joanna!
- Starring works again.

Removed:

- Repost action on posts.


### 2.0 (23) - 2019-04-18
This release is the first after the cut-over to 10Cv5. (If that's news to you, see: https://matigo.ca/2019/04/10/server-down.) Its focus is re-enabling basic interaction with the 10C community. This release is less functional than the previous release was with 10Cv4, but since the previous release didn't support v5 at all, it's a big improvement over something that just crashes on launch.

Basic post display is working.

Login, posting, replying, and post editing work.

View in WebView is broken, and other features haven't even been explored yet.

Many of the streams in 10Cv4 may no longer apply to 10Cv5.
If so, they will be removed in a future release.

Fixed:

- Crash when attempting to show a 10Centuries error message.

Changed:

- Supports 10Cv5 rather than 10Cv4.
- Account display is only half-working now.
- Image upload is as yet untested.

New:

- Displays any non-empty post title above the post.
- Displays any post geo-tag info in post attributes.


### 1.0 (22) - 2019-03-29
Removed:

- iOS 9.3 support. iOS 10.0 or later is now required.

Changed:

- Second- and third-party components have been updated: Xcode 10.2, Swift 5.0, and Kingfisher 5.3.1.


### 1.0 (21) - 2019-01-08
This is a maintenance release.


### 1.0 (20) - 2018-10-03
This is a maintenance release.


### 1.0 (19) - 2018-07-07
This is a maintenance release.


### 1.0 (18) - 2018-04-22
This is a maintenance release.


### 1.0 (17) - 2018-01-20
This is a maintenance release.

Fixed:

- "View in WebView" now uses the latest URL template. [#124]


### 1.0 (16) - 2017-10-25
This is a maintenance release. The app is now using latest Apple toolchain.

Fixed:

- Stream contents are no longer partly hidden under the navigation bar.


### 1.0 (15) - 2017-07-30
Removed:

- "Private" stream is no longer listed. DM support remains unimplemented. [#122]


### 1.0 (14) - 2017-05-18
Changed:

- Profile page now indicates if you're in the follower/following list. [#111]
- ComposePost uses shorter "copy-mention" style `/@abc` rather than `// @abc` for mentions other than the primary one. [#113]
- Post actions now include "View Thread" as an alternative to the "swipe-in" gesture. [#98]


### 1.0 (13) - 2017-03-26
New:

- Tap the avatar on a post to view the user's profile [#25]
- Un/follow an account using a button on its profile page [#26]
- Un/mute an account using a button on its profile page [#101]

   Mutes take effect the next time you reload a stream. The API mostly won't send muted posts, but when it does, they are displayed with a "?????? (you muted this)" line in the post metadata area below the post content.
- Un/silence an account using a button on its profile page [#64]

   WARNING: Careful with this; you can currently only get to an account via a post avatar, and you won't see any posts from users you've silenced, so you won't be able to unsilence them once you leave this page!

Changed:

- Lists (including footnotes) now indent all their lines, not just the first [#97]
- API requests now specify they want only JSON in response, which might improve error display in some weird cases you'll probably never encounter. [#96]

Fixed:

- Footnotes should no longer truncate, but instead word-wrap [#97]
- Starring and pinning a repost will update the repost to show the result [#99]
- Unstar result is now toasted as such, not as starring [#99]
- Unpin result is now toasted as such, not as pinning [#99]


### 1.0 (12) - 2017-03-08
Fixed:

- Rewrote some HTML to valid XML to fix post display. [#55] [#93]
- Forced line-wrapping to avoid unwanted truncation of paragraphs alongside blockquotes. [#87]


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
