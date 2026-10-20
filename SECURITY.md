# Security and diagnostic privacy

Do not post account cookies, provider material, signed stream URLs, signing files, tokens or unredacted device logs in public issues. Contact **appsvorynlabs@gmail.com** for a private security report. Do not include secrets in the initial email; describe the issue first.

Musyn does not bundle JioSaavn provider material. Optional user input is stored in iOS Keychain on that device. No automatic GitHub log-upload token or uploader is included. Diagnostics are redacted locally and uploads require the user's explicit confirmation; a dpaste link is public, not private storage.

Release CI scans tracked files and IPA contents for the removed legacy provider material. The guard has been tested against the old 0.2.0 binary. This is a targeted regression check, not a claim that a general secret audit or external legal review has certified the application.

Historical build withdrawal cannot revoke downloaded copies or forks. The published main branch and current release tag were sanitized with their current source trees preserved. Reclone before contributing: pushing old branches can reintroduce removed material. GitHub cached objects may require support-assisted removal. See [the public-release report](docs/PUBLIC_RELEASE_0.3.0.md) for verified cleanup scope.
