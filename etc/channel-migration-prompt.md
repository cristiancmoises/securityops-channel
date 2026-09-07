# Authenticated private-forge channel migration

Migrate the workstation's active GNU Guix channel sources to the owner's
`git.securityops.com.br/cristiancmoises` namespace, with corresponding mirrors
on `git.securityops.co/cristiancmoises`.

1. Inspect user, root, System and Home channel usage, including transitive
   dependencies. Remove only channels proven unnecessary. Preserve channels
   needed by existing packages and services, even if imported indirectly.
2. Inspect Forgejo through `ev shell ct118`. Use supported Forgejo APIs for
   repository operations; preserve existing repositories, branches and settings.
   Never overwrite a divergent repository or expose access tokens.
3. Inventory each channel's source, branch, pinned revision, introduction and
   keyring. Create missing pull mirrors with complete Git history. Include local
   channel commits that do not exist upstream, without rewriting history.
4. Keep both destination namespaces populated. Verify every selected commit
   and required authentication ref before switching configuration URLs.
5. Use only `.com.br/cristiancmoises` URLs in the active channel list. Explicitly
   list the complete dependency closure so upstream dependency URLs cannot add
   extra channels. Preserve revision pins and authentication introductions.
6. Back up user/root configurations. Apply only with legitimate filesystem
   access; if local root privileges are unavailable, prepare an exact reviewed
   installation command and report that root remains unchanged.
7. Validate Scheme syntax, dependency closure, mirrored commits and signatures.
   Do not run System/Home reconfiguration or build the entire channel set;
   deployment uses the owner's substitute infrastructure.
8. Report mirrors created/reused, retained/removed channels, configuration paths,
   verification results and any unresolved access or synchronization issue.

Execute the plan. Do not claim a mirror, configuration change or authentication
check succeeded without evidence. Do not delete upstream repositories, profile
generations, or historical configuration backups.
