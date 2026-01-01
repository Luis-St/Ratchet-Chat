#!/usr/bin/env node

/**
 * Updates CHANGELOG.md with release notes from a GitHub release.
 *
 * Usage: node update-changelog.mjs <version> <date> <release-body>
 *
 * Environment variables:
 *   RELEASE_BODY - The release body text (alternative to argument)
 */

import fs from "fs";
import path from "path";

const CHANGELOG_PATH = "client/public/CHANGELOG.md";

function parseReleaseBody(body) {
  const sections = [];
  let currentSection = null;

  const lines = body.split("\n");

  for (const line of lines) {
    const trimmed = line.trim();

    // Skip empty lines at the start
    if (!trimmed && !currentSection) continue;

    // Skip "What's Changed" header and "Full Changelog" footer
    if (trimmed.match(/^##?\s*What'?s Changed/i)) continue;
    if (trimmed.match(/^\*?\*?Full Changelog\*?\*?:/i)) continue;
    if (trimmed.match(/^https:\/\/github\.com/)) continue;

    // Check for section headers (### Added, ### Fixed, etc.)
    const sectionMatch = trimmed.match(/^###?\s+(.+)$/);
    if (sectionMatch) {
      const title = sectionMatch[1].trim();
      // Only use standard changelog sections
      if (
        [
          "Added",
          "Changed",
          "Deprecated",
          "Removed",
          "Fixed",
          "Security",
        ].includes(title)
      ) {
        currentSection = { title, items: [] };
        sections.push(currentSection);
        continue;
      }
    }

    // Check for list items
    const itemMatch = trimmed.match(/^[-*]\s+(.+)$/);
    if (itemMatch && currentSection) {
      // Clean up PR references like "by @user in #123"
      let item = itemMatch[1]
        .replace(/\s+by\s+@[\w-]+\s+in\s+#\d+$/i, "")
        .replace(/\s+by\s+@[\w-]+\s+in\s+https:\/\/github\.com\/[^\s]+$/i, "")
        .replace(/\s+in\s+#\d+$/i, "")
        .trim();

      if (item) {
        currentSection.items.push(item);
      }
    } else if (itemMatch && !currentSection) {
      // If we have items but no section, default to "Changed"
      currentSection = { title: "Changed", items: [] };
      sections.push(currentSection);

      let item = itemMatch[1]
        .replace(/\s+by\s+@[\w-]+\s+in\s+#\d+$/i, "")
        .replace(/\s+by\s+@[\w-]+\s+in\s+https:\/\/github\.com\/[^\s]+$/i, "")
        .replace(/\s+in\s+#\d+$/i, "")
        .trim();

      if (item) {
        currentSection.items.push(item);
      }
    }
  }

  // Filter out empty sections
  return sections.filter((s) => s.items.length > 0);
}

function formatChangelogEntry(version, date, sections) {
  let entry = `## [${version}] - ${date}\n`;

  for (const section of sections) {
    entry += `\n### ${section.title}\n`;
    for (const item of section.items) {
      entry += `- ${item}\n`;
    }
  }

  return entry;
}

function updateChangelog(version, date, releaseBody) {
  const sections = parseReleaseBody(releaseBody);

  if (sections.length === 0) {
    console.log("No changelog items found in release body");
    return false;
  }

  const entry = formatChangelogEntry(version, date, sections);

  // Read existing changelog
  let changelog = fs.readFileSync(CHANGELOG_PATH, "utf8");

  // Find the position after the header (after the first ## [...] line)
  const firstEntryMatch = changelog.match(/\n## \[/);
  if (!firstEntryMatch) {
    // No existing entries, append after header
    changelog = changelog.trimEnd() + "\n\n" + entry;
  } else {
    const insertPos = firstEntryMatch.index;
    changelog =
      changelog.slice(0, insertPos) + "\n" + entry + changelog.slice(insertPos);
  }

  fs.writeFileSync(CHANGELOG_PATH, changelog);
  console.log(`Updated changelog with version ${version}`);
  console.log("Sections added:");
  for (const section of sections) {
    console.log(`  - ${section.title}: ${section.items.length} items`);
  }

  return true;
}

// Main
const args = process.argv.slice(2);
const version = args[0];
const date = args[1];
const releaseBody = args[2] || process.env.RELEASE_BODY || "";

if (!version || !date) {
  console.error("Usage: node update-changelog.mjs <version> <date> [body]");
  console.error("  or set RELEASE_BODY environment variable");
  process.exit(1);
}

try {
  const success = updateChangelog(version, date, releaseBody);
  process.exit(success ? 0 : 1);
} catch (error) {
  console.error("Error updating changelog:", error.message);
  process.exit(1);
}
