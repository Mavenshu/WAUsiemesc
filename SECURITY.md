# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in Winget-AutoUpdate, please do not open a public issue.

Instead, use GitHub's private vulnerability reporting feature:

Security → Advisories → Report a vulnerability

Please include, when possible:

- A description of the vulnerability
- Steps to reproduce the issue
- A proof of concept
- The potential security impact
- The affected version(s) of Winget-AutoUpdate

We appreciate responsible disclosure and will work with you to investigate the issue before any public disclosure.

## Antivirus, EDR, and SIEM alerts

Winget-AutoUpdate uses scheduled tasks and PowerShell to install and update applications. Depending on configuration, it runs in system and user contexts and downloads files from Microsoft, GitHub, or an administrator-configured source. These expected operations can generate security alerts.

Before deploying a release:

- Download it from the intended repository and release page.
- Compare the MSI's SHA-256 with the value published in that release. The release workflow calculates and publishes this hash; for a locally built package, calculate and distribute the hash through a trusted channel.
- Treat the hash as an integrity check, not proof of publisher identity. The current release workflow does not Authenticode-sign the MSI or PowerShell scripts. Maintainers should use a publisher-controlled certificate and a protected signing workflow before relying on signer-based trust.

If a security product reports a detection, preserve the alert and review the release, file hash, source, and relevant WAU logs. Submit the detection to the security-product vendor for review, including the detection name, release/version, SHA-256, source URL, and relevant logs.

Do not disable endpoint protection or create broad exclusions for PowerShell, the WAU installation directory, or download domains. Any enterprise allowlisting should be approved by the organization's security team, limited to a verified release or trusted publisher, and reviewed periodically.
