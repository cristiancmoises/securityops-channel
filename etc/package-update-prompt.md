# Complete channel update prompt

Audit every public package and private dependency in this GNU Guix channel
against its authoritative upstream releases. Use the latest stable release
appropriate to each package; record unavailable or ambiguous results explicitly.
Do not treat a missing updater, a failed request, or a version string alone as
proof that a package is current or working.

1. Inspect repository instructions, the worktree, channel dependencies, package
   definitions, installed profiles, and available disk and memory resources.
2. Inventory all definitions, including re-exports, binary packages, vendored
   applications, and private build dependencies. Record upstream evidence.
3. Update recipes and vendored sources using verified downloads and real Guix
   hashes. Preserve licensing notices, source-pruning policies, authentication,
   offline builds, and package-specific patches unless evidence warrants changes.
4. Evaluate every module and derive the exact channel definitions. Use the
   owner's Guix substitute infrastructure for large builds. Run targeted local
   checks where useful; distinguish evaluation from completed builds and tests.
5. Leave installation to the owner's system and Home reconfiguration unless
   explicitly requested otherwise. Do not build every package locally or change
   substitute settings. Preserve existing profiles and rollback generations.
6. Update English and Portuguese documentation with concise tables and dated
   evidence. Distinguish recipe versions, successful builds, and installed state.
   Use no emojis. Record any unresolved limitation without claiming completion.
7. Review the diff, create GPG-signed commits, and push to every configured remote
   without force-pushing. Keep credentials out of tracked files and remote URLs.

Execute this workflow through completion. Never fabricate release versions,
checksums, successful tests, installations, or publication results.
