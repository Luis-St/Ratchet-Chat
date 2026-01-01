"use client"

import { cn } from "@/lib/utils"

type WhatsNewBadgeProps = {
  className?: string
}

export function WhatsNewBadge({ className }: WhatsNewBadgeProps) {
  return (
    <span
      className={cn(
        "absolute -right-1 -top-1 h-2.5 w-2.5 rounded-full bg-accent",
        "animate-pulse",
        className
      )}
      aria-label="New version available"
    />
  )
}
