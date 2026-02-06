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
