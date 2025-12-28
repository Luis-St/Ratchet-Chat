"use client"

import * as React from "react"
import { Copy, Eye, EyeOff, Fingerprint, Lock, LogOut, Monitor, Shield } from "lucide-react"

import { Button } from "@/components/ui/button"
import { cn } from "@/lib/utils"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { Label } from "@/components/ui/label"
import { Switch } from "@/components/ui/switch"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { useAuth, type SessionInfo } from "@/context/AuthContext"
import { useCall } from "@/context/CallContext"
import { useSettings } from "@/hooks/useSettings"
import { Badge } from "@/components/ui/badge"
import { Input } from "@/components/ui/input"

function parseDeviceInfo(userAgent: string | null): string {
  if (!userAgent) return "Unknown device"

  // Simple parsing - extract browser and OS hints
  if (userAgent.includes("Chrome")) {
    if (userAgent.includes("Mobile")) return "Chrome Mobile"
    return "Chrome"
  }
  if (userAgent.includes("Firefox")) return "Firefox"
  if (userAgent.includes("Safari") && !userAgent.includes("Chrome")) return "Safari"
  if (userAgent.includes("Edge")) return "Edge"

  return "Browser"
}

function formatRelativeTime(dateString: string): string {
  const date = new Date(dateString)
  const now = new Date()
  const diffMs = now.getTime() - date.getTime()
  const diffSecs = Math.floor(diffMs / 1000)
  const diffMins = Math.floor(diffSecs / 60)
  const diffHours = Math.floor(diffMins / 60)
  const diffDays = Math.floor(diffHours / 24)

  if (diffDays > 0) return `${diffDays}d ago`
  if (diffHours > 0) return `${diffHours}h ago`
  if (diffMins > 0) return `${diffMins}m ago`
  return "just now"
}

function formatTimestamp(timestamp: number | null): string {
  if (!timestamp) return "Unknown"
  const date = new Date(timestamp)
  if (Number.isNaN(date.getTime())) return "Unknown"
  return `${date.toLocaleString()} (${formatRelativeTime(date.toISOString())})`
}

function formatKeyPreview(key: string, head = 18, tail = 14): string {
  if (!key) return "Unavailable"
  if (key.length <= head + tail + 3) return key
  return `${key.slice(0, head)}...${key.slice(-tail)}`
}

export function SettingsDialog({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { user, publicIdentityKey, deleteAccount, fetchSessions, invalidateSession, invalidateAllOtherSessions, rotateTransportKey, getTransportKeyRotatedAt } = useAuth()
  const { callState } = useCall()
  const { settings, updateSettings } = useSettings()
  const isInActiveCall = callState.status !== "idle" && callState.status !== "ended"
  const [showKey, setShowKey] = React.useState(false)
  const [deleteConfirm, setDeleteConfirm] = React.useState("")
  const [deleteError, setDeleteError] = React.useState<string | null>(null)
  const [isDeleting, setIsDeleting] = React.useState(false)
  const [isRotatingTransportKey, setIsRotatingTransportKey] = React.useState(false)
  const [rotateTransportError, setRotateTransportError] = React.useState<string | null>(null)
  const [transportRotatedAt, setTransportRotatedAt] = React.useState<number | null>(null)
  const [loadingTransportRotatedAt, setLoadingTransportRotatedAt] = React.useState(false)

  // Session management state
  const [sessions, setSessions] = React.useState<SessionInfo[]>([])
  const [loadingSessions, setLoadingSessions] = React.useState(false)
  const [invalidatingSessionId, setInvalidatingSessionId] = React.useState<string | null>(null)

  const identityKey = publicIdentityKey ?? ""
  const identityKeyPreview = formatKeyPreview(identityKey)

  const deleteLabel = user?.handle ?? user?.username ?? ""
  const isDeleteMatch = deleteLabel !== "" && deleteConfirm.trim() === deleteLabel

  // Fetch sessions when dialog opens
  const loadSessions = React.useCallback(async () => {
    setLoadingSessions(true)
    try {
      const data = await fetchSessions()
      setSessions(data)
    } catch {
      // Handle error silently
    } finally {
      setLoadingSessions(false)
    }
  }, [fetchSessions])

  const loadTransportRotation = React.useCallback(async () => {
    setLoadingTransportRotatedAt(true)
    try {
      const timestamp = await getTransportKeyRotatedAt()
      setTransportRotatedAt(timestamp)
    } finally {
      setLoadingTransportRotatedAt(false)
    }
  }, [getTransportKeyRotatedAt])

  React.useEffect(() => {
    if (open) {
      void loadSessions()
      void loadTransportRotation()
    }
  }, [open, loadSessions, loadTransportRotation])

  React.useEffect(() => {
    if (!open) {
      setDeleteConfirm("")
      setDeleteError(null)
      setIsDeleting(false)
      setRotateTransportError(null)
    }
  }, [open])

  const handleInvalidateSession = React.useCallback(async (sessionId: string) => {
    setInvalidatingSessionId(sessionId)
    try {
      await invalidateSession(sessionId)
      setSessions((prev) => prev.filter((s) => s.id !== sessionId))
    } catch {
      // Handle error
    } finally {
      setInvalidatingSessionId(null)
    }
  }, [invalidateSession])

  const handleInvalidateAllOther = React.useCallback(async () => {
    try {
      await invalidateAllOtherSessions()
      setSessions((prev) => prev.filter((s) => s.isCurrent))
    } catch {
      // Handle error
    }
  }, [invalidateAllOtherSessions])

  const handleRotateTransportKey = React.useCallback(async () => {
    // Show extra warning if user is in an active call
    if (isInActiveCall) {
      const callWarningConfirmed = window.confirm(
        "You are currently in a call. Rotating your key now may disrupt the call. Are you sure you want to continue?"
      )
      if (!callWarningConfirmed) {
        return
      }
    }

    const confirmed = window.confirm(
      "Rotate your transport key? Other signed-in devices will be updated."
    )
    if (!confirmed) {
      return
    }
    setRotateTransportError(null)
    setIsRotatingTransportKey(true)
    try {
      await rotateTransportKey()
      void loadTransportRotation()
    } catch (error) {
      setRotateTransportError(
        error instanceof Error ? error.message : "Unable to rotate transport key"
      )
    } finally {
      setIsRotatingTransportKey(false)
    }
  }, [rotateTransportKey, isInActiveCall])

  const handleDeleteAccount = React.useCallback(async () => {
    if (!deleteLabel) return
    if (!isDeleteMatch) {
      setDeleteError(`Type ${deleteLabel} to confirm account deletion.`)
      return
    }
    const confirmed = window.confirm(
      "This will permanently delete your account and all server data. This cannot be undone."
    )
    if (!confirmed) {
      return
    }
    setDeleteError(null)
    setIsDeleting(true)
    try {
      await deleteAccount()
      onOpenChange(false)
    } catch (error) {
      setDeleteError(
        error instanceof Error ? error.message : "Unable to delete account"
      )
    } finally {
      setIsDeleting(false)
    }
  }, [deleteAccount, deleteLabel, isDeleteMatch, onOpenChange])
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[550px] max-h-[85vh] flex flex-col">
        <DialogHeader>
          <DialogTitle>Settings</DialogTitle>
          <DialogDescription>
            Manage your privacy and security preferences.
          </DialogDescription>
        </DialogHeader>
        <Tabs defaultValue="privacy" className="w-full flex-1 min-h-0 flex flex-col">
          <div className="sticky top-0 z-10 bg-background">
            <TabsList className="grid w-full grid-cols-3">
              <TabsTrigger value="privacy">Privacy</TabsTrigger>
              <TabsTrigger value="sessions">Sessions</TabsTrigger>
              <TabsTrigger value="security">Identity</TabsTrigger>
            </TabsList>
          </div>

          <div className="flex-1 min-h-0 overflow-y-auto">
            <TabsContent value="privacy" className="space-y-4 py-4">
            <div className="flex items-center justify-between space-x-2">
              <div className="space-y-1">
                <Label htmlFor="typing" className="text-base">Typing Indicator</Label>
                <p className="text-xs text-muted-foreground">
                  Show others when you are typing.
                </p>
              </div>
              <Switch
                id="typing"
                checked={settings.showTypingIndicator}
                onCheckedChange={(checked) =>
                  updateSettings({ showTypingIndicator: checked })
                }
              />
            </div>
            
            <div className="flex items-center justify-between space-x-2">
              <div className="space-y-1">
                <Label htmlFor="receipts" className="text-base">Read Receipts</Label>
                <p className="text-xs text-muted-foreground">
                  Let others know when you have read their messages.
                </p>
              </div>
              <Switch
                id="receipts"
                checked={settings.sendReadReceipts}
                onCheckedChange={(checked) =>
                  updateSettings({ sendReadReceipts: checked })
                }
              />
            </div>
            </TabsContent>

            <TabsContent value="sessions" className="space-y-4 py-4">
            <div className="space-y-1 mb-4">
              <h3 className="text-sm font-medium">Active Sessions</h3>
              <p className="text-xs text-muted-foreground">
                Devices where you are currently logged in. Sessions expire after 7 days of inactivity.
              </p>
            </div>

            {loadingSessions ? (
              <p className="text-sm text-muted-foreground">Loading sessions...</p>
            ) : (
              <div className="space-y-3 max-h-[300px] overflow-y-auto">
                {sessions.map((session) => (
                  <div
                    key={session.id}
                    className={cn(
                      "flex items-start justify-between rounded-lg border p-3",
                      session.isCurrent && "border-emerald-500 bg-emerald-50/50 dark:bg-emerald-900/10"
                    )}
                  >
                    <div className="flex items-start gap-3">
                      <Monitor className="mt-0.5 h-4 w-4 text-muted-foreground" />
                      <div className="space-y-1">
                        <div className="flex items-center gap-2">
                          <span className="text-sm font-medium">
                            {parseDeviceInfo(session.deviceInfo)}
                          </span>
                          {session.isCurrent && (
                            <Badge variant="outline" className="text-[10px]">
                              Current
                            </Badge>
                          )}
                        </div>
                        <p className="text-xs text-muted-foreground">
                          {session.ipAddress ?? "Unknown IP"} &bull; Created {formatRelativeTime(session.createdAt)}
                        </p>
                        <p className="text-xs text-muted-foreground">
                          Last active {formatRelativeTime(session.lastActiveAt)}
                        </p>
                      </div>
                    </div>
                    {!session.isCurrent && (
                      <Button
                        variant="ghost"
                        size="icon"
                        className="h-8 w-8 text-destructive hover:text-destructive"
                        onClick={() => handleInvalidateSession(session.id)}
                        disabled={invalidatingSessionId === session.id}
                        title="Log out this session"
                      >
                        <LogOut className="h-4 w-4" />
                      </Button>
                    )}
                  </div>
                ))}
              </div>
            )}

            {sessions.length > 1 && (
              <Button
                variant="outline"
                className="w-full mt-4"
                onClick={handleInvalidateAllOther}
              >
                Log out all other sessions
              </Button>
            )}
            </TabsContent>

            <TabsContent value="security" className="space-y-4 py-4">
            <div className="rounded-lg border bg-muted/50 p-4">
              <div className="mb-4 flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Fingerprint className="h-4 w-4 text-emerald-600" />
                  <span className="font-semibold text-sm">Identity Key</span>
                </div>
                <Badge variant="outline" className="text-[10px] font-mono">ML-DSA-65</Badge>
              </div>
              <div className="flex items-start gap-2">
                <div
                  className={cn(
                    "flex-1 min-w-0 max-h-32 rounded-md bg-background p-3 font-mono text-xs border shadow-sm min-h-[3rem] flex items-center overflow-y-auto",
                    showKey ? "break-all" : "truncate whitespace-nowrap"
                  )}
                >
                  {showKey ? identityKey : identityKeyPreview}
                </div>
                <div className="flex flex-col gap-1">
                  <Button
                    variant="outline"
                    size="icon"
                    className="h-9 w-9 bg-background shadow-sm"
                    onClick={() => setShowKey(!showKey)}
                    title={showKey ? "Hide full key" : "View full key"}
                  >
                    {showKey ? (
                      <EyeOff className="h-4 w-4" />
                    ) : (
                      <Eye className="h-4 w-4" />
                    )}
                  </Button>
                  <Button
                    variant="outline"
                    size="icon"
                    className="h-9 w-9 bg-background shadow-sm"
                    onClick={() => navigator.clipboard.writeText(identityKey)}
                    title="Copy key"
                  >
                    <Copy className="h-4 w-4" />
                  </Button>
                </div>
              </div>
              <p className="mt-2 text-[10px] text-muted-foreground">
                Base64 length: {identityKey.length || 0} chars
              </p>
              <p className="mt-3 text-[10px] text-muted-foreground">
                This key publicly identifies you on the network. Friends can verify your identity by comparing this fingerprint.
              </p>
            </div>

            <div className="rounded-lg border bg-muted/50 p-4">
              <div className="mb-3 flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Lock className="h-4 w-4 text-sky-600" />
                  <span className="font-semibold text-sm">Transport Key</span>
                </div>
                <Badge variant="outline" className="text-[10px] font-mono">ML-KEM-768</Badge>
              </div>
              <p className="text-[10px] text-muted-foreground">
                Used to decrypt incoming payloads. Rotating will update your other signed-in devices.
              </p>
              <div className="mt-3 flex items-center justify-between">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={handleRotateTransportKey}
                  disabled={isRotatingTransportKey}
                >
                  {isRotatingTransportKey ? "Rotating..." : "Rotate key"}
                </Button>
              </div>
              <p className="mt-2 text-[10px] text-muted-foreground">
                Last rotated{" "}
                {loadingTransportRotatedAt ? "Loading..." : formatTimestamp(transportRotatedAt)}
              </p>
              {rotateTransportError ? (
                <p className="mt-2 text-[10px] text-destructive">{rotateTransportError}</p>
              ) : null}
            </div>

            <div className="flex items-start gap-3 rounded-lg border border-emerald-200 bg-emerald-50 p-3 dark:border-emerald-900/30 dark:bg-emerald-900/10">
              <Shield className="mt-0.5 h-4 w-4 text-emerald-600 dark:text-emerald-400" />
              <div className="space-y-1">
                <p className="text-xs font-medium text-emerald-900 dark:text-emerald-100">Zero Knowledge</p>
                <p className="text-[10px] text-emerald-700 dark:text-emerald-300">
                  Your private keys never leave your device. The server cannot decrypt your messages.
                </p>
              </div>
            </div>

            <div className="rounded-lg border border-destructive/30 bg-destructive/5 p-4">
              <div className="flex items-start justify-between gap-3">
                <div className="space-y-1">
                  <p className="text-sm font-semibold text-destructive">Delete account</p>
                  <p className="text-xs text-muted-foreground">
                    Permanently remove your account and server-stored encrypted data. This cannot be undone.
                  </p>
                </div>
                <Button
                  variant="destructive"
                  className="shrink-0"
                  disabled={!isDeleteMatch || isDeleting}
                  onClick={handleDeleteAccount}
                >
                  {isDeleting ? "Deleting..." : "Delete"}
                </Button>
              </div>
              <div className="mt-3 space-y-2">
                <Label htmlFor="delete-confirm" className="text-xs">
                  Type your handle to confirm
                </Label>
                <Input
                  id="delete-confirm"
                  value={deleteConfirm}
                  placeholder={deleteLabel || "user@host"}
                  onChange={(event) => {
                    setDeleteConfirm(event.target.value)
                    setDeleteError(null)
                  }}
                />
                {deleteError ? (
                  <p className="text-xs text-destructive">{deleteError}</p>
                ) : null}
              </div>
            </div>
            </TabsContent>
          </div>
        </Tabs>
      </DialogContent>
    </Dialog>
  )
}
