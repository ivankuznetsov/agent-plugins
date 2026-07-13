# Humanize Command

Use this command to identify and remove AI-generated writing patterns from content, making it sound more naturally human-written.

## Usage
`/seo:humanize [file path or paste text]`

## What This Command Does
Analyzes prose for statistical artifacts characteristic of AI-generated writing and rewrites problematic sections while preserving meaning. Based on Wikipedia's "Signs of AI writing" guide.

## AI Writing Patterns to Identify and Remove

### Content Patterns (6)
1. **Inflated significance language** - Words like "pivotal", "testament", "crucial", "broader trends", "underscored"
2. **Overemphasized notability** - Excessive claims about media coverage, recognition, or importance
3. **Superficial "-ing" analyses** - Phrases like "highlighting the...", "showcasing the..."
4. **Promotional language** - Words like "vibrant", "nestled", "stunning", "remarkable"
5. **Vague attributions** - "Many experts say...", "It is widely believed...", "Studies show..."
6. **Formulaic sections** - "Challenges and Future Prospects", "Legacy and Impact" without substance

### Language Patterns (6)
7. **Overused AI vocabulary** - Words like "Additionally", "landscape", "showcase", "interplay", "delve", "multifaceted", "nuanced", "comprehensive", "robust", "leverage", "synergy"
8. **Copula avoidance** - Using "serves as", "boasts", "features" instead of simpler "is/are"
9. **Negative parallelisms** - "Not only...but", "It's not just...", "More than merely..."
10. **Rule of three overuse** - Constant use of three examples, adjectives, or points
11. **Elegant variation** - Excessive synonym cycling to avoid repetition
12. **False ranges** - "from X to Y" without meaningful connection (e.g., "from marketing to relationships")

### Style Patterns (6)
13. **Em dash overuse** - Replace with appropriate punctuation (comma, semicolon, period)
14. **Excessive boldface** - Remove unnecessary bold emphasis
15. **Inline-header lists** - Convert to proper prose or genuine lists
16. **Title Case in headings** - Use sentence case instead
17. **Emoji decoration** - Remove unless specifically requested
18. **Curly quotation marks** - Use straight quotes for consistency

### Communication Patterns (3)
19. **Chatbot artifacts** - Remove "I hope this helps!", "Let me know if you have questions"
20. **Knowledge-cutoff disclaimers** - Remove references to training data limitations
21. **Sycophantic tone** - Remove excessive agreement, praise, or validation

### Filler & Hedging (3)
22. **Filler phrases** - Remove "due to the fact that", "in order to", "it is important to note"
23. **Excessive hedging** - Remove unnecessary qualifications like "it could be argued", "one might say"
24. **Generic conclusions** - Replace with specific, actionable takeaways

## Process

### 1. Read the Content
- If a file path is provided, read the file
- If text is pasted, use that directly

### 2. Analyze for AI Patterns
Scan the text and identify instances of each pattern category. Create a mental inventory of issues.

### 3. Rewrite Problematic Sections
For each identified issue:
- Preserve the core meaning and information
- Use simpler, more natural language
- Add specificity where content is generic
- Replace corporate/AI vocabulary with conversational alternatives

### 4. Add Genuine Voice
Beyond removing patterns, ensure the content has:
- **Opinions and reactions** - Not just neutral reporting
- **Varied rhythm** - Mix short and long sentences
- **Acknowledgment of complexity** - Real nuance, not false balance
- **First-person perspective** - When appropriate for the format
- **Some structural imperfection** - Natural writing isn't always perfectly organized
- **Specificity** - Replace generic statements with concrete details

### 5. Verify Naturalness
Check that the revised version:
- Sounds like a real person wrote it
- Maintains appropriate tone for the audience
- Doesn't contain any remaining AI artifacts
- Flows naturally when read aloud

## Output Format

### Present the humanized content:
```
## Humanized Content

[Full revised text with AI patterns removed]
```

### Optionally show changes summary:
```
## Changes Made

### Content Patterns Addressed
- [List of specific changes]

### Language Patterns Addressed
- [List of specific changes]

### Style Patterns Addressed
- [List of specific changes]
```

## Example Transformations

### Before (AI-style):
"The podcast landscape has witnessed a pivotal transformation, showcasing the remarkable interplay between content creators and their audiences. Additionally, this comprehensive guide delves into the multifaceted world of podcasting."

### After (Human-style):
"Podcasting has changed a lot in the past few years. More people are making shows, and listeners have more choices than ever. This guide covers what you actually need to know to start your own podcast."

### Before (AI-style):
"It is widely believed that podcast monetization represents a crucial opportunity for content creators. The industry's robust growth underscores the potential for leveraging audio content."

### After (Human-style):
"You can make money from podcasting. It's not guaranteed, but plenty of creators do it through sponsorships, memberships, and products. Here's how the money side actually works."

## Integration with Write Command

After running `/seo:write` or `/seo:rewrite`, you can optionally run `/seo:humanize` to:
1. Remove any AI patterns that slipped through
2. Add more natural voice and personality
3. Ensure the content passes AI detection tools

## Best Practices

1. **Don't over-humanize** - The goal is natural, not artificially casual
2. **Maintain accuracy** - Don't sacrifice correctness for naturalness
3. **Preserve brand voice** - Reference @context/brand-voice.md for tone guidelines
4. **Keep the expertise** - The content should still be authoritative and helpful
5. **Read it aloud** - If it sounds weird spoken, it needs more work

## File Management

If humanizing a file, save the result to:
- **Same location** - Overwrite the original with humanized version
- **Backup first** - Optionally save original as `[filename]-original.md`

---

**Result**: Content that is indistinguishable from naturally human-written text while maintaining quality and accuracy.
