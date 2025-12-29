"use client"

import * as React from "react"
import { Ban, Copy, Eye, EyeOff, Fingerprint, Shield, Trash2, UserPlus } from "lucide-react"

import { Button } from "@/components/ui/button"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { Badge } from "@/components/ui/badge"
import { Separator } from "@/components/ui/separator"
import type { Contact } from "@/types/dashboard"

export function RecipientInfoDialog({
  contact,
  open,
  onOpenChange,
  onBlockUser,
  onAddContact,
  onRemoveContact,
}: {
  contact: Contact | null
  open: boolean
  onOpenChange: (open: boolean) => void
  onBlockUser?: (contact: Contact) => void
  onAddContact?: (contact: Contact) => void
  onRemoveContact?: (contact: Contact) => void
}) {
  const [showIdentityKey, setShowIdentityKey] = React.useState(false)

  React.useEffect(() => {
    if (!contact) {
      return
    }
    setShowIdentityKey(false)
  }, [contact?.handle, open])

  if (!contact) return null

  const formatKeyPreview = (key: string, head = 18, tail = 14) => {
    if (!key) return "Unavailable"
    if (key.length <= head + tail + 3) return key
    return `${key.slice(0, head)}...${key.slice(-tail)}`
  }
  const identityKeyPreview = formatKeyPreview(contact.publicIdentityKey)

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[425px]">
        <DialogHeader>
          <DialogTitle>Contact Info</DialogTitle>
          <DialogDescription>
            Identity details for this secure session.
          </DialogDescription>
        </DialogHeader>
        
        <div className="flex flex-col items-center gap-4 py-4">
          <Avatar className="h-24 w-24">
            <AvatarImage src="" />
            <AvatarFallback className="text-2xl bg-emerald-600 text-white">
              {contact.username.slice(0, 2).toUpperCase()}
            </AvatarFallback>
          </Avatar>
          
          <div className="text-center space-y-1">
            <h3 className="text-xl font-semibold">{contact.username}</h3>
            <p className="text-sm text-muted-foreground">{contact.handle}</p>
          </div>

          <div className="w-full space-y-4 mt-2">
            <div className="rounded-lg border bg-muted/50 p-4">
              <div className="mb-3 flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Fingerprint className="h-4 w-4 text-emerald-600" />
                  <span className="font-semibold text-sm">Identity Key</span>
                </div>
                <Badge variant="outline" className="text-[10px] font-mono">ML-DSA-65</Badge>
              </div>
              
              <div className="flex items-start gap-2">
                <div
                  className={
                    showIdentityKey
                      ? "flex-1 min-w-0 max-h-32 rounded-md bg-background p-3 font-mono text-xs break-all border shadow-sm min-h-[3rem] flex items-center overflow-y-auto"
                      : "flex-1 min-w-0 max-h-32 rounded-md bg-background p-3 font-mono text-xs border shadow-sm min-h-[3rem] flex items-center truncate whitespace-nowrap overflow-y-auto"
                  }
                >
                  {showIdentityKey ? contact.publicIdentityKey : identityKeyPreview}
                </div>
                <div className="flex flex-col gap-1">
                  <Button
                    variant="outline"
                    size="icon"
                    className="h-9 w-9 bg-background shadow-sm shrink-0"
                    onClick={() => setShowIdentityKey(!showIdentityKey)}
                    title={showIdentityKey ? "Hide full key" : "View full key"}
                  >
                    {showIdentityKey ? (
                      <EyeOff className="h-4 w-4" />
                    ) : (
                      <Eye className="h-4 w-4" />
                    )}
                  </Button>
                  <Button
                    variant="outline"
                    size="icon"
                    className="h-9 w-9 bg-background shadow-sm shrink-0"
                    onClick={() => navigator.clipboard.writeText(contact.publicIdentityKey)}
                    title="Copy key"
                  >
                    <Copy className="h-4 w-4" />
                  </Button>
                </div>
              </div>
              <p className="mt-2 text-[10px] text-muted-foreground">
                Base64 length: {contact.publicIdentityKey.length || 0} chars
              </p>
            </div>

            <div className="flex items-start gap-3 rounded-lg border border-emerald-200 bg-emerald-50 p-3 dark:border-emerald-900/30 dark:bg-emerald-900/10">
              <Shield className="mt-0.5 h-4 w-4 text-emerald-600 dark:text-emerald-400 shrink-0" />
              <div className="space-y-1">
                <p className="text-xs font-medium text-emerald-900 dark:text-emerald-100">Verified Session</p>
                <p className="text-[10px] text-emerald-700 dark:text-emerald-300">
                  Messages are end-to-end encrypted. Verify this identity key with your contact to ensure security.
                </p>
              </div>
            </div>
          </div>

          {(onBlockUser || onRemoveContact || onAddContact) && (
            <div className="w-full pt-2">
              <Separator className="mb-3" />
              <div className="space-y-2">
                <p className="text-xs font-semibold uppercase text-muted-foreground">Actions</p>
                <div className="flex flex-col gap-2">
                  {onAddContact && (
                    <Button
                      variant="outline"
                      onClick={() => onAddContact(contact)}
                    >
                      <UserPlus className="mr-2 h-4 w-4" />
                      Add to contacts
                    </Button>
                  )}
                  {onBlockUser && (
                    <Button
                      variant="destructive"
                      onClick={() => onBlockUser(contact)}
                    >
                      <Ban className="mr-2 h-4 w-4" />
                      Block User
                    </Button>
                  )}
                  {onRemoveContact && (
                    <Button
                      variant="outline"
                      onClick={() => onRemoveContact(contact)}
                    >
                      <Trash2 className="mr-2 h-4 w-4" />
                      Remove from contacts
                    </Button>
                  )}
                </div>
              </div>
            </div>
          )}
        </div>
      </DialogContent>
    </Dialog>
  )
}
