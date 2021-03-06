# Releasing

- Bump version in Info.plist:

  ```
  vi src/Info.plist
  /BundleVers<RET>
  jl
  C-a
  :wq
  ```

- Update ThirdPartyLicenses.txt if any libraries were updated.

- Update change log by looking at past merges and what's in the
  [latest milestone](https://gitlab.com/jeremy-w/macchiato/milestones).

- Archive a build. Paste the changelog for that version into the archive info.
  Upload to App Store.

- Tag the build and push all:

  ```
  NUM=X git tag -a "v2.0_($NUM)" -m "TF-$NUM" && git push --follow-tags
  ```

- [Visit App Store Connect][asc-tf] once the build goes through,
  drop in the changelog entry in the "what to test" bit,
  add it for testing, and push it out to testers.

  [asc-tf]: https://appstoreconnect.apple.com/WebObjects/iTunesConnect.woa/ra/ng/app/1195479159/testflight

- Announce the release by [posting to 10C][post].
  (Only if it wasn't just a "keep TestFlight working" release.)

  [post]: https://macchiato.10centuries.org/write
