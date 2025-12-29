export interface DeduplicationConfig {
  maxSize: number
  ttlMs: number
}

const DEFAULT_CONFIG: DeduplicationConfig = {
  maxSize: 1000,
  ttlMs: 5 * 60 * 1000, // 5 minutes
}

export class DeduplicationService {
  private processed: Map<string, number> = new Map()
  private config: DeduplicationConfig
  private cleanupInterval: ReturnType<typeof setInterval> | null = null

  constructor(config: Partial<DeduplicationConfig> = {}) {
    this.config = { ...DEFAULT_CONFIG, ...config }
    this.startCleanup()
  }

  isDuplicate(key: string): boolean {
    const timestamp = this.processed.get(key)
    if (!timestamp) {
      return false
    }
    // Check if entry has expired
    if (Date.now() - timestamp > this.config.ttlMs) {
      this.processed.delete(key)
      return false
    }
    return true
  }

  markProcessed(key: string): void {
    this.processed.set(key, Date.now())
    this.enforceMaxSize()
  }

  has(key: string): boolean {
    return this.isDuplicate(key)
  }

  private enforceMaxSize(): void {
    if (this.processed.size <= this.config.maxSize) {
      return
    }
    // Remove oldest half when limit exceeded
    const entries = Array.from(this.processed.entries()).sort(
      (a, b) => a[1] - b[1]
    )
    const toRemove = entries.slice(0, Math.floor(this.config.maxSize / 2))
    for (const [key] of toRemove) {
      this.processed.delete(key)
    }
  }

  private startCleanup(): void {
    this.cleanupInterval = setInterval(() => {
      const now = Date.now()
      for (const [key, timestamp] of this.processed) {
        if (now - timestamp > this.config.ttlMs) {
          this.processed.delete(key)
        }
      }
    }, 60_000) // Cleanup every minute
  }

  size(): number {
    return this.processed.size
  }

  clear(): void {
    this.processed.clear()
    if (this.cleanupInterval) {
      clearInterval(this.cleanupInterval)
      this.cleanupInterval = null
    }
  }
}
