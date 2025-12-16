# TmZ-001: Documentation Formatting Standards

This document proposes a consistent formatting structure for all markdown documents in the Zenon Developer Commons repository. This proposal is meant to serve as a guide rather than a rigid requirement.  

---

## Motivation

As the repository grows, inconsistent formatting creates friction:

- Documents with plain text headings don't render correctly in GitBook
- Mixed list styles (tabs vs dashes) cause display issues
- Lack of structure makes documents harder to navigate
- Contributors are uncertain about expected format

A standard format improves readability, maintainability, and GitBook compatibility.

---

## Proposed Structure

### Document Header

Every document should begin with:

```markdown
# Document Title

Research Note — Brief Descriptor (e.g., "Exploratory", "Draft Notes", "Terminology")

One or two sentences describing the document's purpose and scope. Include any important caveats (e.g., "This is exploratory research, not a specification.").

---

## First Section
```

**Rationale:**
- Single H1 title at the top
- Subtitle line provides context without cluttering the title
- Brief intro before diving into sections
- Horizontal rule separates header from content

---

### Heading Hierarchy

| Level | Syntax | Usage |
|-------|--------|-------|
| H1 | `#` | Document title only (one per document) |
| H2 | `##` | Major sections |
| H3 | `###` | Subsections |
| H4 | `####` | Rarely needed; avoid deep nesting |

**Example:**
```markdown
# Momentum Data Fields

## 1. Observable Properties

### 1.1 Header Structure

Content here.

### 1.2 Hash Commitment

Content here.

## 2. Implications
```

**Rationale:**
- Clear visual hierarchy
- GitBook renders headings in navigation
- Numbered sections (optional) aid cross-referencing

---

### Lists

Use `-` (dash) for all unordered lists:

```markdown
Benefits of this approach:

- Simpler verification
- No global state required
- Browser-compatible
```

**Avoid:**
- Tab-indented bullets
- Plain text on separate lines
- Mixing `*` and `-`

**Rationale:**
- Consistent rendering across platforms
- Clear visual distinction from paragraphs

---

### Section Separators

Use `---` (horizontal rule) between major sections:

```markdown
## Section One

Content here.

---

## Section Two

More content.
```

**Rationale:**
- Visual breathing room
- Clear section boundaries
- Renders well in GitBook and GitHub

---

### Code and Technical Content

Use fenced code blocks with language hints:

````markdown
```go
type Momentum struct {
    Height uint64
    Hash   [32]byte
}
```
````

For inline code, use backticks: `ChangesHash`, `AccountBlock`.

---

### Tables

Use standard markdown tables for structured comparisons:

```markdown
| Property | Traditional Chain | Zenon |
|----------|-------------------|-------|
| Execution | Global | Local |
| Verification | Replay | Predicate |
```

---

### Links and References

**Internal links:**
```markdown
See [Account Chain Commitments](../notes/account-chain-commitments.md) for details.
```

**External links:**
```markdown
Reference: [Bitcoin Whitepaper](https://bitcoin.org/bitcoin.pdf)
```

---

### PDFs and Assets

PDFs cannot be linked directly in GitBook navigation. Create a wrapper page:

```markdown
# Document Title

Brief description of the PDF content.

## Download

<a href="filename.pdf" target="_blank">Download the full document (PDF)</a>

## Related Documents

- [Related Doc One](related-doc.md)
```

---

## Index Files (README.md)

Each directory should have a README.md that:

1. Describes the folder's purpose
2. Organizes documents by category
3. Links to all documents in the folder

**Example structure:**
```markdown
# Research

Brief description of this folder.

---

## Category One

- [Document A](document-a.md)
- [Document B](document-b.md)

---

## Category Two

- [Document C](document-c.md)
```

---

## Potential: YAML Front Matter

Front matter provides structured metadata at the top of documents. This is optional but could enable future tooling (search, filtering, status tracking).

**Example:**
```yaml
---
title: Account-Chain Commitments
type: research-note
status: draft
created: 2025-01-15
updated: 2025-03-20
tags:
  - light-client
  - verification
  - spv
---
```

**Possible fields:**

| Field | Description | Values |
|-------|-------------|--------|
| `title` | Document title | Free text |
| `type` | Document category | `research-note`, `draft`, `proposal`, `specification`, `reference` |
| `status` | Maturity level | `draft`, `review`, `stable`, `deprecated` |
| `created` | Creation date | YYYY-MM-DD |
| `updated` | Last modified | YYYY-MM-DD |
| `tags` | Topics covered | List of keywords |
| `related` | Linked documents | List of paths |

**Pros:**
- Machine-readable metadata
- Enables automated indexes and filtering
- Clear document lifecycle tracking
- Standard pattern (Jekyll, Hugo, GitBook, Obsidian)

**Cons:**
- Added complexity for contributors
- Requires maintenance discipline
- May not render in all viewers
- GitBook support varies by version

**Discussion point:** Is front matter worth the overhead, or should metadata stay informal (in the subtitle/intro)?

---

## Open Questions

1. **Front matter**: Should we adopt YAML front matter (see above), or keep it simple?

2. **Document categories**: Should we define document types (Research Note, Draft, Proposal, Specification)?

3. **Status tracking**: How should we indicate document maturity (draft, stable, deprecated)?

---

## Implementation

If accepted, this standard would apply to:

- All new documents
- Existing documents (reformatted incrementally)

---

## Feedback

Please comment on this proposal with:

- Suggested changes
- Alternative approaches
- Questions or concerns
