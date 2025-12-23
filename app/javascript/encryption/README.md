# Encryption Files

This directory should contain the encryption modules for generating X-Bogus and X-Gnarly tokens.

## Required Files

1. `xbogus.mjs` - X-Bogus token generator
2. `xgnarly.mjs` - X-Gnarly token generator

## How to Obtain

Download these files from:
https://github.com/justbeluga/tiktok-web-reverse-engineering/tree/main/encryption

Place them in this directory (`app/javascript/encryption/`).

## Expected Exports

- `xbogus.mjs` should export a default function: `(queryString, bodyString, userAgent, timestamp) => string`
- `xgnarly.mjs` should export a default function: `(queryString, bodyString, userAgent, timestamp, version) => string`

