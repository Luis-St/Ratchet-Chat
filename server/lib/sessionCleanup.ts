import type { PrismaClient } from "@prisma/client";

const CLEANUP_INTERVAL_MS = 60 * 60 * 1000; // 1 hour

export function startSessionCleanup(prisma: PrismaClient) {
  const cleanup = async () => {
    try {
      const deleted = await prisma.session.deleteMany({
        where: { expires_at: { lt: new Date() } },
      });
      if (deleted.count > 0) {
        console.log(`Cleaned up ${deleted.count} expired sessions`);
      }
    } catch (error) {
      console.error("Session cleanup error:", error);
    }
  };

  // Run immediately on startup
  void cleanup();

  // Then run periodically
  const intervalId = setInterval(cleanup, CLEANUP_INTERVAL_MS);

  // Return cleanup function
  return () => clearInterval(intervalId);
}
