import type { NextFunction, Request, Response } from "express";

type RateLimitOptions = {
  windowMs: number;
  max: number;
  keyPrefix: string;
  keyGenerator?: (req: Request) => string | null;
  skip?: (req: Request) => boolean;
};

type RateLimitEntry = {
  count: number;
  resetAt: number;
};

const buckets = new Map<string, RateLimitEntry>();
const MAX_BUCKETS = Number(process.env.RATE_LIMIT_MAX_BUCKETS ?? 50000);

const cleanupBuckets = (now: number) => {
  if (buckets.size <= MAX_BUCKETS) {
    return;
  }
  for (const [key, entry] of buckets) {
    if (entry.resetAt <= now) {
      buckets.delete(key);
    }
    if (buckets.size <= MAX_BUCKETS) {
      break;
    }
  }
};

export const createRateLimiter = (options: RateLimitOptions) => {
  return (req: Request, res: Response, next: NextFunction) => {
    if (options.skip?.(req)) {
      return next();
    }
    const keyBase = options.keyGenerator?.(req) ?? req.ip ?? "";
    if (!keyBase) {
      return next();
    }
    const key = `${options.keyPrefix}:${keyBase}`;
    const now = Date.now();
    let entry = buckets.get(key);
    if (!entry || entry.resetAt <= now) {
      entry = { count: 0, resetAt: now + options.windowMs };
    }
    entry.count += 1;
    buckets.set(key, entry);
    cleanupBuckets(now);

    const remaining = Math.max(0, options.max - entry.count);
    res.setHeader("X-RateLimit-Limit", options.max.toString());
    res.setHeader("X-RateLimit-Remaining", remaining.toString());
    res.setHeader("X-RateLimit-Reset", Math.ceil(entry.resetAt / 1000).toString());

    if (entry.count > options.max) {
      return res.status(429).json({ error: "Rate limit exceeded" });
    }
    return next();
  };
};
