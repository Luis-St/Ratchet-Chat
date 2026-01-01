export type ChangelogSection = {
  title: string
  items: string[]
}

export type ChangelogEntry = {
  version: string
  date: string
  sections: ChangelogSection[]
}

const VERSION_HEADER_REGEX = /^## \[([^\]]+)\](?: - (.+))?$/
const SECTION_HEADER_REGEX = /^### (.+)$/
const LIST_ITEM_REGEX = /^- (.+)$/

export function parseChangelog(markdown: string): ChangelogEntry[] {
  const lines = markdown.split("\n")
  const entries: ChangelogEntry[] = []
  let currentEntry: ChangelogEntry | null = null
  let currentSection: ChangelogSection | null = null

  for (const line of lines) {
    const trimmed = line.trim()

    const versionMatch = trimmed.match(VERSION_HEADER_REGEX)
    if (versionMatch) {
      if (currentSection && currentEntry) {
        currentEntry.sections.push(currentSection)
      }
      if (currentEntry) {
        entries.push(currentEntry)
      }
      currentEntry = {
        version: versionMatch[1],
        date: versionMatch[2] ?? "",
        sections: [],
      }
      currentSection = null
      continue
    }

    const sectionMatch = trimmed.match(SECTION_HEADER_REGEX)
    if (sectionMatch && currentEntry) {
      if (currentSection) {
        currentEntry.sections.push(currentSection)
      }
      currentSection = {
        title: sectionMatch[1],
        items: [],
      }
      continue
    }

    const itemMatch = trimmed.match(LIST_ITEM_REGEX)
    if (itemMatch && currentSection) {
      currentSection.items.push(itemMatch[1])
    }
  }

  if (currentSection && currentEntry) {
    currentEntry.sections.push(currentSection)
  }
  if (currentEntry) {
    entries.push(currentEntry)
  }

  return entries
}

export async function fetchChangelog(): Promise<ChangelogEntry[]> {
  try {
    const response = await fetch("/CHANGELOG.md")
    if (!response.ok) {
      return []
    }
    const text = await response.text()
    return parseChangelog(text)
  } catch {
    return []
  }
}
