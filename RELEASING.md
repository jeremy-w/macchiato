# Releasing

- Bump version in Info.plist:

  ```
  vi src/Info.plist
  /BundleVers<RET>
  jl
  C-a
  :wq
  ```

- Update change log by looking at past merges and what's in the
  [latest milestone](https://gitlab.com/jeremy-w/macchiato/milestones).

- Archive a build. Paste the changelog for that version into the archive info.
  Upload to App Store.

- Tag the build and push all:

  ```
  git tag -a 'v1.0_(NUM)' -m 'TF-NUM'
  git push --all
  ```

- Visit iTunes Connect once the build goes through, drop in the changelog entry
  in the "what to test" bit, add it for testing, and push it out to testers.
- Announce the release by posting to 10C.
