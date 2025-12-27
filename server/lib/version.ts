import fs from "fs";
import path from "path";

function resolveGitDir(startDir: string): string | null {
  let current = startDir;
  for (let i = 0; i < 6; i += 1) {
    const gitPath = path.join(current, ".git");
    if (fs.existsSync(gitPath)) {
      const stat = fs.statSync(gitPath);
      if (stat.isDirectory()) {
        return gitPath;
      }
      if (stat.isFile()) {
        const content = fs.readFileSync(gitPath, "utf8").trim();
        const match = content.match(/^gitdir:\s*(.+)$/);
        if (match) {
          return path.resolve(current, match[1]);
        }
      }
    }
    const parent = path.dirname(current);
    if (parent === current) {
      break;
    }
    current = parent;
  }
  return null;
}

function readRef(gitDir: string, ref: string): string | null {
  const refPath = path.join(gitDir, ref);
  if (fs.existsSync(refPath)) {
    return fs.readFileSync(refPath, "utf8").trim() || null;
  }
  const packedRefsPath = path.join(gitDir, "packed-refs");
  if (!fs.existsSync(packedRefsPath)) {
    return null;
  }
  const packed = fs.readFileSync(packedRefsPath, "utf8");
  const lines = packed.split("\n");
  for (const line of lines) {
    if (!line || line.startsWith("#") || line.startsWith("^")) {
      continue;
    }
    const [hash, refName] = line.split(" ");
    if (refName === ref) {
      return hash;
    }
  }
  return null;
}

export function getGitCommit(startDir = process.cwd()): string | null {
  try {
    const gitDir = resolveGitDir(startDir);
    if (!gitDir) {
      return null;
    }
    const headPath = path.join(gitDir, "HEAD");
    if (!fs.existsSync(headPath)) {
      return null;
    }
    const head = fs.readFileSync(headPath, "utf8").trim();
    if (!head) {
      return null;
    }
    if (head.startsWith("ref:")) {
      const ref = head.replace(/^ref:\s*/, "");
      return readRef(gitDir, ref);
    }
    return head;
  } catch {
    return null;
  }
}
