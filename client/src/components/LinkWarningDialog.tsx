"use client"

import * as React from "react"
import { ExternalLink } from "lucide-react"

import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"

export function LinkWarningDialog({
  url,
  open,
  onOpenChange,
}: {
  url: string | null
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  if (!url) return null

  let hostname = ""
  try {
    hostname = new URL(url).hostname
  } catch {
    hostname = url
  }

  const handleContinue = () => {
    window.open(url, "_blank", "noopener,noreferrer")
    onOpenChange(false)
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[425px]">
        <DialogHeader>
          <DialogTitle>External Link Warning</DialogTitle>
          <DialogDescription>
            You are about to leave Ratchet Chat.
          </DialogDescription>
        </DialogHeader>
        <div className="flex flex-col gap-4 py-4">
          <div className="rounded-md bg-muted p-3 text-sm break-all flex items-center gap-2">
            <ExternalLink className="h-4 w-4 shrink-0 text-muted-foreground" />
            <span className="font-medium">{hostname}</span>
          </div>
          <p className="text-sm text-muted-foreground">
            This link leads to an external website. We cannot verify the security of external sites.
          </p>
          <p className="text-xs text-muted-foreground break-all font-mono bg-muted/50 p-2 rounded">
            {url}
          </p>
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button onClick={handleContinue}>
            Continue
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
