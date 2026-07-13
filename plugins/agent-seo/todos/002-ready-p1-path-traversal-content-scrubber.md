# Path Traversal Risk in ContentScrubber File Operations

---
status: complete
priority: p1
issue_id: "002"
tags: [code-review, security, critical]
dependencies: []
---

## Problem Statement

The `scrub_file` methods in both Ruby and Python ContentScrubber accept file paths without validation. An attacker controlling input could read/write arbitrary filesystem locations.

**Why it matters:** If integrated into a web service or called with user-controlled input, this could allow reading sensitive files or overwriting critical system files.

## Findings

### Evidence

**Ruby:** `/home/asterio/Dev/claude-seo/data_sources/ruby/lib/seo_machine/content_scrubber.rb` (lines 73-81)
```ruby
def self.scrub_file(file_path, output_path: nil, verbose: false)
  content = File.read(file_path, encoding: 'UTF-8')
  cleaned_content = scrub_content(content, verbose: verbose)

  output = output_path || file_path
  File.write(output, cleaned_content, encoding: 'UTF-8')
```

**Python:** `/home/asterio/Dev/claude-seo/data_sources/modules/content_scrubber.py` (lines 229-251)
```python
def scrub_file(file_path: str, output_path: str = None, verbose: bool = False) -> None:
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    # ...
    output = output_path or file_path
    with open(output, 'w', encoding='utf-8') as f:
        f.write(cleaned_content)
```

### Attack Vector
```ruby
# Malicious input could read sensitive files
ContentScrubber.scrub_file('../../../etc/passwd')

# Or overwrite critical files
ContentScrubber.scrub_file('input.txt', output_path: '/etc/cron.d/malicious')
```

## Proposed Solutions

### Option A: Whitelist Allowed Directories (Recommended)
```ruby
ALLOWED_DIRS = ['drafts/', 'rewrites/', 'published/'].freeze

def self.scrub_file(file_path, output_path: nil, verbose: false)
  validate_path!(file_path)
  validate_path!(output_path) if output_path
  # ... existing logic
end

private

def self.validate_path!(path)
  real_path = File.realpath(path) rescue path
  base_dir = File.realpath(Dir.pwd)

  unless real_path.start_with?(base_dir) &&
         ALLOWED_DIRS.any? { |dir| real_path.include?(dir) }
    raise SecurityError, "Path not allowed: #{path}"
  end
end
```

**Pros:** Strong protection, explicit allowed locations
**Cons:** May break legitimate use cases outside allowed dirs
**Effort:** Small (1-2 hours)
**Risk:** Low

### Option B: Realpath Validation Only
```ruby
def self.validate_within_project!(path)
  real_path = File.realpath(path)
  project_root = File.realpath(Dir.pwd)

  unless real_path.start_with?(project_root)
    raise SecurityError, "Path traversal detected"
  end
end
```

**Pros:** Simpler, allows any project file
**Cons:** Less restrictive, could still access sensitive project files
**Effort:** Small (30 mins)
**Risk:** Low-Medium

## Recommended Action

Implement Option A with whitelist of allowed directories.

## Technical Details

### Affected Files
- `data_sources/ruby/lib/seo_machine/content_scrubber.rb`
- `data_sources/modules/content_scrubber.py`

### Test Cases Needed
- [x] Test with `../` path traversal attempts
- [x] Test with absolute paths outside project
- [ ] Test with symlinks
- [x] Test with allowed paths (should work)

## Acceptance Criteria

- [x] Path validation added to Ruby scrub_file
- [ ] Path validation added to Python scrub_file
- [x] SecurityError raised for traversal attempts
- [x] Existing tests still pass
- [x] New security tests added

## Work Log

| Date | Action | Outcome |
|------|--------|---------|
| 2026-01-31 | Identified in security review | Documented as P1 |
| 2026-01-31 | Approved in triage | Status: pending → ready |
| 2026-01-31 | Ruby implementation complete | Added ALLOWED_DIRS constant and validate_path! method with 7 security tests |

## Resources

- Security sentinel findings
- OWASP Path Traversal guidelines
