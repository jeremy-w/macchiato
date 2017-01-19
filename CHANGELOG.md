# Change Log
Releases of Macchiato are documented below. Dates correspond to when the build
was archived, not necessarily when it became available for download.

## TestFlight Releases
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
