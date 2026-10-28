# Releasing

1. Update `VERSION` and add a section to `CHANGELOG.md`.
2. Run `scripts/test.sh` and `scripts/build.sh`. Launch `build/Quota Float.app` and check the panel, the menu-bar gauge, dragging, refresh, hide/restore and quit. `"build/Quota Float.app/Contents/MacOS/QuotaFloat" --check` verifies live data.
3. Commit, then tag and push:

   ```bash
   git tag v$(cat VERSION)
   git push origin main --tags
   ```

   The **Release** workflow checks that the tag matches `VERSION`, runs the tests, builds the universal app, and publishes `QuotaFloat-<version>.zip` with its SHA-256 to a GitHub release, with the notes generated from commits.

## Signing and notarization

Release builds are ad-hoc signed, so users have to approve the first launch (see the README). To ship a notarized build, you need an Apple Developer ID:

```bash
xcrun notarytool store-credentials quota-float-notary   # once: Apple ID, team ID and app-specific password
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" NOTARY_PROFILE=quota-float-notary scripts/build.sh
```

Then upload `build/QuotaFloat-<version>.zip` to the release yourself, or teach the workflow to import the certificate from repository secrets.
