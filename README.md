# Markdown Spotlight importer

Add Markdown contents to the Mac OS X Spotlight index and parse the YAML frontmatter

## YAML Frontmatter

Supported YAML keys:

- title
- keywords, tags (split on comma)
- project, projects
- attendees, participants
- date (parses using NSDataDetector)


Values:
Fields can be a single line after the key or multiple lines all starting with a hyphen.