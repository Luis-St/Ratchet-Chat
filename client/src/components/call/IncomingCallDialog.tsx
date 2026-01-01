"use client"

import { Phone, PhoneOff, Video } from "lucide-react"
import { Button } from "@/components/ui/button"
import {
  ResponsiveModal,
  ResponsiveModalContent,
  ResponsiveModalDescription,
  ResponsiveModalHeader,
  ResponsiveModalTitle,
} from "@/components/ui/responsive-modal"
import { Avatar, AvatarFallback } from "@/components/ui/avatar"
import { resumeAudioContext } from "./AudioLevelIndicator"
import type { CallType } from "@/context/CallContext"

type IncomingCallDialogProps = {
  open: boolean
  callerHandle: string
  callType: CallType
  onAccept: () => void
  onReject: () => void
  onSilence?: () => void
}

export function IncomingCallDialog({
  open,
  callerHandle,
  callType,
  onAccept,
  onReject,
  onSilence,
}: IncomingCallDialogProps) {
  const username = callerHandle.split("@")[0]
  const initials = username.slice(0, 2).toUpperCase()
  const isVideo = callType === "VIDEO"

  const handleAccept = () => {
    // Resume AudioContext on user gesture for Safari
    resumeAudioContext()
    onAccept()
  }

  return (
    <ResponsiveModal
      open={open}
      onOpenChange={(nextOpen) => {
        if (!nextOpen && onSilence) {
          onSilence()
        }
      }}
    >
      <ResponsiveModalContent
        className="sm:max-w-sm !z-[10000]"
        // Drawer doesn't support overlayClassName directly in the same way, but it's handled by ResponsiveModal
        onPointerDownOutside={(e) => e.preventDefault()}
        onEscapeKeyDown={(e) => e.preventDefault()}
      >
        <ResponsiveModalHeader className="items-center text-center">
          <Avatar className="size-20 mb-4">
            <AvatarFallback className="text-2xl">{initials}</AvatarFallback>
          </Avatar>
          <ResponsiveModalTitle className="text-xl">{username}</ResponsiveModalTitle>
          <ResponsiveModalDescription className="text-base">
            Incoming {isVideo ? "video" : "voice"} call
          </ResponsiveModalDescription>
        </ResponsiveModalHeader>

        <div className="flex justify-center gap-6 mt-6">
          <Button
            variant="nuclear"
            size="icon-lg"
            onClick={onReject}
            className="rounded-full size-14"
            title="Decline"
          >
            <PhoneOff className="size-6" />
          </Button>

          <Button
            variant="accept"
            size="icon-lg"
            onClick={handleAccept}
            className="rounded-full size-14"
            title="Accept"
          >
            {isVideo ? <Video className="size-6" /> : <Phone className="size-6" />}
          </Button>
        </div>
      </ResponsiveModalContent>
    </ResponsiveModal>
  )
}
