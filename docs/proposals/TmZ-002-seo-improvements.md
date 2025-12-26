---
description: Proposal to add YAML frontmatter descriptions to all Zenon Developer Commons markdown files for improved search engine visibility and social sharing.
---

# TmZ-002: SEO Improvements

This document proposes SEO improvements for the Zenon Developer Commons documentation through YAML frontmatter adoption. This proposal itself demonstrates the frontmatter approach.

---

## Motivation

GitBook automatically handles most SEO fundamentals (robots.txt, sitemap, Open Graph tags), but page descriptions are empty by default. Adding YAML frontmatter descriptions to all markdown files will populate meta descriptions and improve search engine visibility.

---

## Current State

**Hosting:**
- Hosted on GitBook.io cloud (uses GitBook's rendering, not HonKit)
- GitBook reads `description` from YAML frontmatter in markdown files
- Local preview uses HonKit 6.1.4 (`honkit serve`)

**Provided automatically by GitBook:**
- `robots.txt` — crawler directives
- `sitemap.xml` — page index for search engines
- `llms.txt` — content index for AI agents
- Open Graph tags — derived from page title and description

**Current meta description (empty):**
```html
<meta name="description" content="">
```

**Missing Metadata:**
- No YAML frontmatter in any markdown files

---

## Proposed Changes

### Add YAML Frontmatter to All Markdown Files

Add a `description` field to all markdown files. GitBook Git Sync reads the `description` frontmatter field and uses it for:

- `<meta name="description">` — improves search engine snippets
- `og:description` — improves social sharing previews

#### Frontmatter Template

```yaml
---
description: [Up to 200 character description of page content for SEO and social sharing]
---

# Document Title
```

#### Example Descriptions

**`docs/README.md`**
```yaml
---
description: Technical research documentation for Zenon Network of Momentum. Explore architecture, light clients, bounded verification, and decentralized infrastructure.
---
```

**`docs/architecture/architecture-overview.md`**
```yaml
---
description: High-level overview of Zenon NoM architecture including momentums, account-chain DAG, node types, and Application Contract Interfaces (ACIs).
---
```

**`docs/research/browser-light-client-overview.md`**
```yaml
---
description: Feasibility analysis for browser-native Zenon light clients using WebRTC, libp2p, and SPV-style verification without trusted servers.
---
```

**`docs/research/bounded-verification-series.md`**
```yaml
---
description: Multi-part research series on Zenon bounded verification including header-only verification, bounded inclusion, and minimal state frontier techniques.
---
```

---

## Files to Modify

60 markdown files will receive YAML frontmatter with SEO descriptions:

| Directory | File Count |
|-----------|------------|
| Root | 1 |
| Architecture | 3 |
| Research | 21 |
| Notes | 24 |
| Proposals | 3 |
| Specs | 3 |
| Feasibility | 2 |
| AZ | 3 |

See appendix for complete file list.

---

## Implementation Plan

1. Create `seo` branch after proposal acceptance
2. Add frontmatter to all markdown files (batch by directory)
3. Test locally with `honkit serve`
4. Verify generated HTML has populated meta descriptions
5. Submit PR for review

---

## Benefits

- **Search Engine Visibility**: Meaningful descriptions in search results
- **Social Sharing**: Better previews when links are shared
- **Future Tooling**: Frontmatter enables automated indexes and filtering
- **Contributor Guidance**: Clear template for new documents

---

## Compatibility Notes

- **GitBook.io Cloud**: Git Sync reads `description` from frontmatter and populates meta tags and Open Graph tags automatically
- **HonKit Local**: Full compatibility with `honkit serve` for local preview
- **YAML Frontmatter**: Standard pattern used by Jekyll, Hugo, GitBook, and Obsidian

