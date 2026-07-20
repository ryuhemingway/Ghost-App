# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in Ghost, please report it privately via GitHub's [Security Advisories](https://github.com/ryuhemingway/Ghost-App/security/advisories/new) page.

**Do not open a public issue.** This gives maintainers time to patch before the vulnerability is disclosed.

## Supported Versions

| Version | Supported |
| ------- | --------- |
| 1.1.x   | Yes       |
| < 1.1   | No        |

## Security Model

Ghost is designed to be local-first with strong isolation between providers, permissions, and data access. Key architectural decisions:

- API keys are stored in macOS Keychain, not in plaintext files
- Each provider only sees its own key during execution
- Local providers (Ollama, LM Studio) cannot launch agent mode
- A web egress guard blocks private network requests (localhost, RFC 1918, link-local, multicast)
- File access requires user-approved folder scope and explicit permission
- All capabilities are opt-in and disabled by default on first launch

If you find a way to bypass these controls, please report it.
