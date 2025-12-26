import { createHash } from "crypto";
import type { NextFunction, Request, Response } from "express";
import jwt from "jsonwebtoken";
import type { PrismaClient } from "@prisma/client";

export type AuthenticatedUser = {
  id: string;
  username: string;
};

declare module "express-serve-static-core" {
  interface Request {
    user?: AuthenticatedUser;
    sessionId?: string;
  }
}

export const getJwtSecret = (): string => {
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    throw new Error("JWT_SECRET is not set");
  }
  return secret;
};

export const hashToken = (token: string): string => {
  return createHash("sha256").update(token).digest("hex");
};

export const createAuthenticateToken = (prisma: PrismaClient) => {
  return async (req: Request, res: Response, next: NextFunction) => {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const token = authHeader.slice("Bearer ".length);
    try {
      const secret = getJwtSecret();
      const payload = jwt.verify(token, secret) as jwt.JwtPayload;
      if (!payload.sub || typeof payload.sub !== "string") {
        return res.status(401).json({ error: "Unauthorized" });
      }

      // Validate session exists in database
      const tokenHash = hashToken(token);
      const session = await prisma.session.findUnique({
        where: { token_hash: tokenHash },
        select: { id: true, expires_at: true, user_id: true },
      });

      if (!session) {
        return res.status(401).json({ error: "Session invalidated" });
      }

      if (session.expires_at < new Date()) {
        // Clean up expired session
        await prisma.session.delete({ where: { id: session.id } });
        return res.status(401).json({ error: "Session expired" });
      }

      const username =
        typeof payload.username === "string" ? payload.username : "";
      req.user = { id: payload.sub, username };
      req.sessionId = session.id;
      return next();
    } catch (error) {
      return res.status(401).json({ error: "Unauthorized" });
    }
  };
};

// Legacy function for backwards compatibility during migration
export const authenticateToken = (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).json({ error: "Unauthorized" });
  }

  const token = authHeader.slice("Bearer ".length);
  try {
    const secret = getJwtSecret();
    const payload = jwt.verify(token, secret) as jwt.JwtPayload;
    if (!payload.sub || typeof payload.sub !== "string") {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const username =
      typeof payload.username === "string" ? payload.username : "";
    req.user = { id: payload.sub, username };
    return next();
  } catch (error) {
    return res.status(401).json({ error: "Unauthorized" });
  }
};
