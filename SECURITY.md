# Security and diagnostic privacy

Do not post account cookies, provider material, signed stream URLs, signing files, tokens or unredacted device logs in public issues. Contact **appsvorynlabs@gmail.com** for a private security report. Do not include secrets in the initial email; describe the issue first.

Musyn does not bundle JioSaavn provider material. Optional user input is stored in iOS Keychain on that device. No automatic GitHub log-upload token or uploader is included. Diagnostics are redacted locally and uploads require the user's explicit confirmation; a dpaste link is public, not private storage.

Release CI scans tracked files and IPA contents for removed legacy provider material. This targeted regression check complements dependency and code review; it is not a general secret scan or external legal certification.

Historical build withdrawal cannot revoke downloaded copies or forks. The published main branch and current release tag were sanitized with their current source trees preserved. Reclone before contributing: pushing old branches can reintroduce removed material. GitHub cached objects may require support-assisted removal.
