# Work on Next Roadmap Item

1. Read ROADMAP.md
2. Identify the highest priority item that is not in-progress or completed
3. Show me the item and ask for confirmation before starting
4. Once confirmed, mark it as `[-]` in-progress with today's date in ROADMAP.md
5. Assess complexity:
   - If the feature is straightforward (< 5 steps, no blocking dependencies), work through it directly without formal task tracking
   - If the feature is complex with genuine dependencies between phases, break it into Tasks using TaskCreate with addBlockedBy for sequential phases
6. Begin implementation, updating task status as you go (if tasks were created)
7. Run lint and tests after each meaningful change
8. After all steps complete and tests pass, mark the roadmap item as `[x]` completed with today's date
9. Move it to the "Recently Completed" section
10. Update the Obsidian project note:
    - Search Obsidian for the project note (use `obsidian_simple_search` with the project name, look for notes with `tags: code` in frontmatter)
    - If found, update these sections using `obsidian_patch_content` (operation: replace):
      - **Aktueller Stand**: What was just completed and what's next (1-2 sentences)
      - **Nächste Prioritäten**: Re-read ROADMAP.md and list the current top items
      - **Letzte Änderungen**: Prepend the completed item with today's date (keep the last ~5 entries)
      - **updated** frontmatter field: Set to today's date
    - Write in German. Keep entries concise.
    - If no project note is found, skip this step silently — not all projects have one
