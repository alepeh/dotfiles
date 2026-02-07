Create a short-form changelog entry ("diff") for the Hugo site at `site/content/diff/`.

## Steps

1. **Identify the PR**: Check the current git branch. If on a feature branch, use `gh pr list --head <branch> --json number,title,url,mergedAt,state` to find the associated PR. If on `main` or no PR is found, ask the user which PR to cover (by number or URL).

2. **Gather context**: Run these to understand the change:
   - `gh pr view <number> --json title,body,url,mergedAt,number` for PR metadata
   - `gh pr diff <number>` for the actual diff
   - Use the PR merge date (`mergedAt`) — this becomes the entry's `date` field

3. **Draft the entry**:
   - **Title**: Start from the PR title; adjust for clarity if needed
   - **Slug**: Derive a kebab-case slug from the title
   - **Tags**: Auto-suggest 1–3 tags based on what changed (e.g., "Zellij", "Neovim", "Shell")
   - **Summary**: One sentence for the frontmatter `summary` field
   - **Body**: Write a single paragraph (3–5 sentences) that combines *what changed* and *why*. Be concrete — mention specific config keys, files, or tools. Keep it conversational but informative.

4. **Present the draft**: Show the full markdown file to the user, including frontmatter and body. Ask for feedback.

5. **Iterate**: If the user wants changes, revise and re-present. Repeat until they approve the paragraph.

6. **Write the file**: Once approved, create `site/content/diff/<slug>.md` with:
   - `draft: false`
   - `date` set to the PR merge date (not today)
   - All frontmatter fields populated
   - The approved paragraph as the body

7. **Confirm**: Show the full file path and a preview. Do **not** auto-commit — the user will commit when ready.

## Frontmatter Template

```yaml
---
title: "<title>"
date: <PR merge date, YYYY-MM-DD format>
draft: false
tags: [<suggested tags>]
summary: "<one-line summary>"
pr: "<full PR URL>"
---
```

## Important

- The `date` field must be the PR's merge date, not today's date
- Keep the body to a single paragraph — this is short-form content
- Use `draft: false` since the user is reviewing before write
- Do not create a git commit — let the user handle that
