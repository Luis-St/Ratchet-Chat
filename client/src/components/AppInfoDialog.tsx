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
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { ScrollArea } from "@/components/ui/scroll-area"
import { apiFetch } from "@/lib/api"
import { cn } from "@/lib/utils"
import { getInstanceHost } from "@/lib/handles"
import { fetchChangelog, type ChangelogEntry } from "@/lib/changelog"

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

export type AppInfoDialogProps = {
  children: React.ReactNode
  defaultTab?: "status" | "changelog"
  onTabChange?: (tab: string) => void
}

export function AppInfoDialog({ children, defaultTab = "status", onTabChange }: AppInfoDialogProps) {
  const [open, setOpen] = React.useState(false)
  const [activeTab, setActiveTab] = React.useState(defaultTab)
  const [health, setHealth] = React.useState<HealthPayload | null>(null)
  const [loadingHealth, setLoadingHealth] = React.useState(false)
  const [healthError, setHealthError] = React.useState<string | null>(null)
  const [changelog, setChangelog] = React.useState<ChangelogEntry[]>([])
  const [loadingChangelog, setLoadingChangelog] = React.useState(false)

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

  const loadChangelog = React.useCallback(async () => {
    setLoadingChangelog(true)
    try {
      const entries = await fetchChangelog()
      setChangelog(entries)
    } finally {
      setLoadingChangelog(false)
    }
  }, [])

  React.useEffect(() => {
    if (open) {
      void loadHealth()
      void loadChangelog()
    }
  }, [open, loadHealth, loadChangelog])

  React.useEffect(() => {
    if (open) {
      setActiveTab(defaultTab)
    }
  }, [open, defaultTab])

  const handleTabChange = React.useCallback((value: string) => {
    setActiveTab(value as "status" | "changelog")
    onTabChange?.(value)
  }, [onTabChange])

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
        <Tabs value={activeTab} onValueChange={handleTabChange} className="w-full">
          <TabsList className="w-full">
            <TabsTrigger value="status" className="flex-1">Status</TabsTrigger>
            <TabsTrigger value="changelog" className="flex-1">Changelog</TabsTrigger>
          </TabsList>

          <TabsContent value="status" className="space-y-4">
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
          </TabsContent>

          <TabsContent value="changelog">
            <ScrollArea className="h-[300px] pr-4">
              {loadingChangelog ? (
                <p className="text-sm text-muted-foreground">Loading changelog...</p>
              ) : changelog.length === 0 ? (
                <p className="text-sm text-muted-foreground">No changelog available.</p>
              ) : (
                <div className="space-y-6">
                  {changelog.map((entry) => (
                    <div key={entry.version} className="space-y-3">
                      <div className="flex items-baseline justify-between gap-2">
                        <h3 className="text-sm font-semibold">v{entry.version}</h3>
                        {entry.date && (
                          <span className="text-xs text-muted-foreground">{entry.date}</span>
                        )}
                      </div>
                      {entry.sections.map((section) => (
                        <div key={section.title} className="space-y-1">
                          <h4 className="text-xs font-medium text-muted-foreground">{section.title}</h4>
                          <ul className="space-y-0.5 text-xs">
                            {section.items.map((item, index) => (
                              <li key={index} className="flex gap-2">
                                <span className="text-muted-foreground">-</span>
                                <span>{item}</span>
                              </li>
                            ))}
                          </ul>
                        </div>
                      ))}
                    </div>
                  ))}
                </div>
              )}
            </ScrollArea>
          </TabsContent>
        </Tabs>
      </ResponsiveModalContent>
    </ResponsiveModal>
  )
}

export { appVersion }
