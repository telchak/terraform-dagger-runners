# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly.

**Do not open a public GitHub issue for security vulnerabilities.**

Instead, please email **sami.chibani.pro@gmail.com** with:

- A description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

You should receive a response within 48 hours. We will work with you to understand the issue and coordinate a fix before any public disclosure.

## Scope

This project provides Terraform modules that deploy infrastructure. Security concerns include but are not limited to:

- Overly permissive RBAC configurations
- Secrets exposed in Terraform state or logs
- Container images with known vulnerabilities
- Insecure default configurations

## Supported Versions

Security fixes are applied to the latest release only.
