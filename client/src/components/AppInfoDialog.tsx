"use client"

import * as React from "react"

import {
  ResponsiveModal,
  ResponsiveModalContent,
  ResponsiveModalDescription,
  ResponsiveModalHeader,
  ResponsiveModalTitle,
  ResponsiveModalTrigger,
} from "@/components/ui/responsive-modal"
import { apiFetch } from "@/lib/api"
import { cn } from "@/lib/utils"
import { getInstanceHost } from "@/lib/handles"

type HealthPayload = {
  status?: string
  commit?: string
  timestamp?: string
}

const rawClientCommit =
  process.env.NEXT_PUBLIC_CLIENT_COMMIT ??
  process.env.NEXT_PUBLIC_GIT_COMMIT_SHA ??
  process.env.NEXT_PUBLIC_VERCEL_GIT_COMMIT_SHA ??
  "unknown"

const appVersion = process.env.NEXT_PUBLIC_APP_VERSION ?? "unknown"

function formatCommit(commit: string | null | undefined) {
  const normalized = (commit ?? "").trim()
  if (!normalized) {
    return { short: "unknown", full: "unknown" }
  }
  if (normalized.length <= 12) {
    return { short: normalized, full: normalized }
  }
  return { short: `${normalized.slice(0, 7)}...`, full: normalized }
}

function formatTimestamp(timestamp?: string) {
  if (!timestamp) return "Unknown"
  const date = new Date(timestamp)
  if (Number.isNaN(date.getTime())) return "Unknown"
  return date.toLocaleString()
}

export function AppInfoDialog({ children }: { children: React.ReactNode }) {
  const [open, setOpen] = React.useState(false)
  const [health, setHealth] = React.useState<HealthPayload | null>(null)
  const [loadingHealth, setLoadingHealth] = React.useState(false)
  const [healthError, setHealthError] = React.useState<string | null>(null)

  const clientCommit = formatCommit(rawClientCommit)
  const serverCommit = formatCommit(health?.commit)
  const instanceHost = getInstanceHost()
  const versionLabel = appVersion === "unknown" ? "unknown" : `v${appVersion}`

  const loadHealth = React.useCallback(async () => {
    setLoadingHealth(true)
    setHealthError(null)
    try {
      const data = await apiFetch<HealthPayload>("/health")
      setHealth(data)
    } catch (error) {
      setHealth(null)
      setHealthError(error instanceof Error ? error.message : "Unavailable")
    } finally {
      setLoadingHealth(false)
    }
  }, [])

  React.useEffect(() => {
    if (open) {
      void loadHealth()
    }
  }, [open, loadHealth])

  const statusLabel = loadingHealth
    ? "Checking..."
    : healthError
      ? "Unreachable"
      : health?.status ?? "Unknown"
  const statusTone = healthError
    ? "text-destructive"
    : health?.status === "ok"
      ? "text-emerald-600"
      : "text-muted-foreground"

  return (
    <ResponsiveModal open={open} onOpenChange={setOpen}>
      <ResponsiveModalTrigger asChild>{children}</ResponsiveModalTrigger>
      <ResponsiveModalContent className="sm:max-w-[480px]">
        <ResponsiveModalHeader>
          <ResponsiveModalTitle>Ratchet Chat</ResponsiveModalTitle>
          <ResponsiveModalDescription>End-to-end encrypted client status.</ResponsiveModalDescription>
        </ResponsiveModalHeader>
        <div className="space-y-4">
          <div className="rounded-lg border bg-muted/50 p-4">
            <div className="text-sm font-semibold">Version</div>
            <div className="mt-2 flex items-center justify-between text-xs">
              <span className="text-muted-foreground">App</span>
              <span className="font-mono">{versionLabel}</span>
            </div>
          </div>

          <div className="rounded-lg border bg-muted/50 p-4">
            <div className="flex items-center justify-between">
              <span className="text-sm font-semibold">Host server</span>
              <span className={cn("text-xs font-semibold", statusTone)}>{statusLabel}</span>
            </div>
            <p className="mt-1 text-xs text-muted-foreground">
              {instanceHost ?? "Unknown host"}
            </p>
            <div className="mt-3 space-y-1 text-xs">
              <div className="flex items-center justify-between">
                <span className="text-muted-foreground">Server time</span>
                <span className="font-mono">
                  {loadingHealth ? "Loading..." : formatTimestamp(health?.timestamp)}
                </span>
              </div>
            </div>
          </div>

          <div className="rounded-lg border bg-muted/50 p-4">
            <div className="mb-2 text-sm font-semibold">Build info</div>
            <div className="space-y-1 text-xs">
              <div className="flex items-center justify-between">
                <span className="text-muted-foreground">Client</span>
                <span className="font-mono" title={clientCommit.full}>
                  {clientCommit.short}
                </span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-muted-foreground">Server</span>
                <span className="font-mono" title={serverCommit.full}>
                  {loadingHealth ? "Loading..." : serverCommit.short}
                </span>
              </div>
            </div>
            {healthError ? (
              <p className="mt-2 text-[10px] text-destructive">
                Unable to reach server health endpoint.
              </p>
            ) : null}
          </div>
        </div>
      </ResponsiveModalContent>
    </ResponsiveModal>
  )
}
