"use client"

import * as React from "react"
import { FileIcon, Paperclip, Send, X } from "lucide-react"
import TextareaAutosize from "react-textarea-autosize"

import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { getContactDisplayName } from "@/lib/contacts"
import type { StoredMessage } from "@/types/dashboard"
import { truncateText, getReplyPreviewText } from "@/lib/messageUtils"

type AttachmentPreview = {
  name: string
  type: string
  size: number
  data: string
}

type ComposeAreaProps = {
  activeContact: {
    handle: string
    username: string
    nickname?: string | null
  } | null
  composeText: string
  onComposeTextChange: (text: string) => void
  editingMessage: StoredMessage | null
  replyToMessage: StoredMessage | null
  attachments: AttachmentPreview[]
  isBusy: boolean
  sendError: string | null
  textareaRef: React.RefObject<HTMLTextAreaElement | null>
  fileInputRef: React.RefObject<HTMLInputElement | null>
  onCancelEdit: () => void
  onCancelReply: () => void
  onRemoveAttachment: (index: number) => void
  onClearAttachments: () => void
  onFileSelect: (e: React.ChangeEvent<HTMLInputElement>) => void
  onTyping: () => void
  onSubmit: () => void
  onPaste: (event: React.ClipboardEvent<HTMLTextAreaElement>) => void
  onUnselectChat: () => void
}

export function ComposeArea({
  activeContact,
  composeText,
  onComposeTextChange,
  editingMessage,
  replyToMessage,
  attachments,
  isBusy,
  sendError,
  textareaRef,
  fileInputRef,
  onCancelEdit,
  onCancelReply,
  onRemoveAttachment,
  onClearAttachments,
  onFileSelect,
  onTyping,
  onSubmit,
  onPaste,
  onUnselectChat,
}: ComposeAreaProps) {
  const replySenderLabel = replyToMessage
    ? replyToMessage.direction === "out"
      ? "You"
      : replyToMessage.peerUsername ?? replyToMessage.peerHandle ?? "Unknown"
    : "Unknown"

  const replyPreviewText = replyToMessage
    ? truncateText(getReplyPreviewText(replyToMessage), 80)
    : ""

  return (
    <div className="flex-none border-t bg-background/80 px-3 py-2 backdrop-blur sm:px-5 sm:py-4">
      {editingMessage && (
        <div className="mb-3 flex items-center justify-between gap-3 rounded-lg border border-emerald-200 bg-emerald-50 px-3 py-2 text-xs text-emerald-900 dark:border-emerald-900/30 dark:bg-emerald-900/20 dark:text-emerald-100">
          <div className="min-w-0">
            <p className="font-semibold">Editing message</p>
            <p className="truncate text-[10px] text-emerald-700 dark:text-emerald-300">
              {editingMessage.text}
            </p>
          </div>
          <Button
            variant="ghost"
            size="icon-sm"
            className="text-emerald-700 hover:text-emerald-900 dark:text-emerald-200 dark:hover:text-emerald-50"
            onClick={onCancelEdit}
            title="Cancel editing"
          >
            <X className="h-4 w-4" />
          </Button>
        </div>
      )}
      {!editingMessage && replyToMessage ? (
        <div className="mb-3 flex items-center justify-between gap-3 rounded-lg border border-emerald-200 bg-emerald-50 px-3 py-2 text-xs text-emerald-900 dark:border-emerald-900/30 dark:bg-emerald-900/20 dark:text-emerald-100">
          <div className="min-w-0">
            <p className="font-semibold">Replying to {replySenderLabel}</p>
            <p className="truncate text-[10px] text-emerald-700 dark:text-emerald-300">
              {replyPreviewText}
            </p>
          </div>
          <Button
            variant="ghost"
            size="icon-sm"
            className="text-emerald-700 hover:text-emerald-900 dark:text-emerald-200 dark:hover:text-emerald-50"
            onClick={onCancelReply}
            title="Cancel reply"
          >
            <X className="h-4 w-4" />
          </Button>
        </div>
      ) : null}
      {attachments.length > 0 && (
        <div className="mb-3 rounded-lg border bg-card p-2 shadow-sm">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs text-muted-foreground">
              {attachments.length} file{attachments.length > 1 ? "s" : ""} ({(attachments.reduce((sum, a) => sum + a.size, 0) / 1024 / 1024).toFixed(1)} MB)
            </span>
            {attachments.length > 1 && (
              <Button
                variant="ghost"
                size="sm"
                className="h-6 px-2 text-xs text-muted-foreground hover:text-destructive"
                onClick={onClearAttachments}
              >
                Clear all
              </Button>
            )}
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-2">
            {attachments.map((attachment, index) => (
              <div
                key={index}
                className="relative group flex items-center gap-2 rounded-md border bg-muted/50 p-1.5"
              >
                {attachment.type.startsWith("image/") ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={`data:${attachment.type};base64,${attachment.data}`}
                    alt="Preview"
                    className="h-8 w-8 rounded object-cover shrink-0"
                  />
                ) : (
                  <div className="flex h-8 w-8 items-center justify-center rounded bg-muted shrink-0">
                    <FileIcon className="h-4 w-4 text-muted-foreground" />
                  </div>
                )}
                <div className="flex flex-col min-w-0 flex-1">
                  <span className="text-[10px] font-medium truncate">
                    {attachment.name}
                  </span>
                  <span className="text-[9px] text-muted-foreground">
                    {attachment.size < 1024 * 1024
                      ? `${(attachment.size / 1024).toFixed(0)} KB`
                      : `${(attachment.size / 1024 / 1024).toFixed(1)} MB`}
                  </span>
                </div>
                <Button
                  variant="ghost"
                  size="icon-sm"
                  className="absolute -top-1 -right-1 h-5 w-5 rounded-full bg-background border shadow-sm opacity-0 group-hover:opacity-100 transition-opacity text-muted-foreground hover:text-destructive"
                  onClick={() => onRemoveAttachment(index)}
                  title="Remove"
                >
                  <X className="h-3 w-3" />
                </Button>
              </div>
            ))}
          </div>
        </div>
      )}
      <Card className="border-border bg-card/90 shadow-sm">
        <CardContent className="flex items-center gap-2 p-2 sm:gap-3 sm:p-3">
          <input
            type="file"
            className="hidden"
            ref={fileInputRef}
            onChange={onFileSelect}
            multiple
          />
          <Button
            variant="ghost"
            size="icon"
            className="text-muted-foreground shrink-0"
            onClick={() => fileInputRef.current?.click()}
            disabled={!activeContact || isBusy || Boolean(editingMessage)}
            aria-label="Attach file"
          >
            <Paperclip />
          </Button>
          <TextareaAutosize
            ref={textareaRef}
            placeholder={
              editingMessage
                ? "Edit message"
                : activeContact
                ? `Message ${getContactDisplayName(activeContact)}`
                : "Select a chat to start messaging"
            }
            className="flex-1 min-h-[34px] max-h-[160px] w-full resize-none border-none bg-transparent py-1.5 px-0 text-sm shadow-none focus-visible:ring-0 outline-none sm:min-h-[40px] sm:py-2.5"
            value={composeText}
            onChange={(event) => {
              onComposeTextChange(event.target.value)
              onTyping()
            }}
            onPaste={onPaste}
            onKeyDown={(event) => {
              if (event.key === "Escape") {
                if (attachments.length > 0) {
                  event.preventDefault()
                  onClearAttachments()
                  return
                }
                if (replyToMessage) {
                  event.preventDefault()
                  onCancelReply()
                  return
                }
                if (!editingMessage && !composeText.trim()) {
                  event.preventDefault()
                  onUnselectChat()
                }
                return
              }
              if (event.key === "Enter" && !event.shiftKey) {
                event.preventDefault()
                onSubmit()
              }
            }}
            disabled={!activeContact || isBusy}
          />
          <Button
            variant="accept"
            className="h-9 w-9 shrink-0 p-0 sm:h-10 sm:w-10"
            disabled={
              (!composeText.trim() && (attachments.length === 0 || Boolean(editingMessage))) ||
              !activeContact ||
              isBusy
            }
            onClick={onSubmit}
            aria-label={editingMessage ? "Save message" : "Send message"}
          >
            <Send className="h-4 w-4" />
          </Button>
        </CardContent>
      </Card>
      {sendError ? (
        <p className="mt-2 text-center text-xs text-destructive">{sendError}</p>
      ) : null}
    </div>
  )
}
