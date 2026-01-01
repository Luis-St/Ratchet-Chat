"use client"

import * as React from "react"
import * as DialogPrimitive from "@radix-ui/react-dialog"
import { X } from "lucide-react"

import { cn } from "@/lib/utils"

const Dialog = DialogPrimitive.Root

const DialogTrigger = DialogPrimitive.Trigger

const DialogPortal = DialogPrimitive.Portal

const DialogClose = DialogPrimitive.Close

const DialogOverlay = React.forwardRef<
  React.ElementRef<typeof DialogPrimitive.Overlay>,
  React.ComponentPropsWithoutRef<typeof DialogPrimitive.Overlay>
>(({ className, ...props }, ref) => (
  <DialogPrimitive.Overlay
    ref={ref}
    className={cn(
      "fixed inset-0 z-50 bg-black/80  data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0",
      className
    )}
    {...props}
  />
))
DialogOverlay.displayName = DialogPrimitive.Overlay.displayName

const DialogContent = React.forwardRef<
  React.ElementRef<typeof DialogPrimitive.Content>,
  React.ComponentPropsWithoutRef<typeof DialogPrimitive.Content> & {
    overlayClassName?: string
  }
>(({ className, children, overlayClassName, ...props }, ref) => {
  const closeRef = React.useRef<HTMLButtonElement>(null)
  const [isMobile, setIsMobile] = React.useState(false)
  const [isDragging, setIsDragging] = React.useState(false)
  const [dragOffset, setDragOffset] = React.useState(0)
  const dragOffsetRef = React.useRef(0)
  const startYRef = React.useRef(0)
  const swipeAxisRef = React.useRef<"x" | "y" | null>(null)
  const startScrollTopRef = React.useRef(0)

  React.useEffect(() => {
    if (typeof window === "undefined") {
      return
    }

    const media = window.matchMedia("(max-width: 640px)")
    const update = () => setIsMobile(media.matches)
    update()
    media.addEventListener("change", update)
    return () => media.removeEventListener("change", update)
  }, [])

  const updateDragOffset = (nextOffset: number) => {
    dragOffsetRef.current = nextOffset
    setDragOffset(nextOffset)
  }

  const getScrollableParent = (element: HTMLElement | null): HTMLElement | null => {
    if (!element) return null
    if (element.scrollHeight > element.clientHeight && element.scrollTop > 0) {
      return element
    }
    return getScrollableParent(element.parentElement)
  }

  const handleTouchStart = (event: React.TouchEvent<HTMLDivElement>) => {
    if (!isMobile) return
    const touch = event.touches[0]
    if (!touch) return

    swipeAxisRef.current = null
    startYRef.current = touch.clientY

    // Check if any scrollable parent is scrolled
    const scrollableParent = getScrollableParent(event.target as HTMLElement)
    startScrollTopRef.current = scrollableParent?.scrollTop ?? 0
  }

  const handleTouchMove = (event: React.TouchEvent<HTMLDivElement>) => {
    if (!isMobile) return
    const touch = event.touches[0]
    if (!touch) return

    const dy = touch.clientY - startYRef.current
    const dx = Math.abs(touch.clientX - (event.touches[0]?.clientX ?? 0))

    // Determine swipe axis if not set
    if (!swipeAxisRef.current) {
      if (Math.abs(dy) < 10 && dx < 10) return
      swipeAxisRef.current = Math.abs(dy) > dx ? "y" : "x"
    }

    if (swipeAxisRef.current !== "y") return

    // Only allow drag-to-close when at the top of scroll
    if (startScrollTopRef.current > 0) return
    if (dy <= 0) return // Only drag down

    if (!isDragging) {
      setIsDragging(true)
    }

    updateDragOffset(Math.max(0, dy))
  }

  const handleTouchEnd = () => {
    if (!isMobile) return

    swipeAxisRef.current = null

    if (!isDragging) return

    setIsDragging(false)

    const threshold = Math.min(150, window.innerHeight * 0.2)
    if (dragOffsetRef.current > threshold) {
      closeRef.current?.click()
      updateDragOffset(0)
      return
    }

    updateDragOffset(0)
  }

  const contentStyle =
    isMobile && dragOffset > 0
      ? { ...props.style, transform: `translate3d(0, ${dragOffset}px, 0)` }
      : props.style

  return (
    <DialogPortal>
      <DialogOverlay className={overlayClassName} />
      <DialogPrimitive.Content
        ref={ref}
        className={cn(
          "fixed inset-0 z-50 grid h-[100dvh] w-full max-w-none gap-4 border border-border/70 bg-background px-6 pt-8 pb-[calc(env(safe-area-inset-bottom)+1.5rem)] shadow-2xl transition-transform overflow-y-auto data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 data-[state=closed]:slide-out-to-bottom-6 data-[state=open]:slide-in-from-bottom-6 data-[dragging=true]:duration-0 data-[dragging=true]:ease-linear sm:inset-auto sm:left-[50%] sm:top-[50%] sm:h-auto sm:max-h-[85vh] sm:max-w-lg sm:translate-x-[-50%] sm:translate-y-[-50%] sm:overflow-y-auto sm:rounded-lg sm:p-6 sm:shadow-lg sm:data-[state=closed]:zoom-out-95 sm:data-[state=open]:zoom-in-95 sm:data-[state=closed]:slide-out-to-left-1/2 sm:data-[state=closed]:slide-out-to-top-[48%] sm:data-[state=open]:slide-in-from-left-1/2 sm:data-[state=open]:slide-in-from-top-[48%]",
          className
        )}
        data-dragging={isDragging ? "true" : "false"}
        style={contentStyle}
        onTouchStart={handleTouchStart}
        onTouchMove={handleTouchMove}
        onTouchEnd={handleTouchEnd}
        {...props}
      >
        {isMobile ? (
          <div
            className="absolute inset-x-0 top-0 z-10 flex h-6 items-center justify-center"
            aria-hidden="true"
          >
            <span className="h-1 w-10 rounded-full bg-foreground/20" />
          </div>
        ) : null}
        {children}
        <DialogPrimitive.Close
          ref={closeRef}
          className="sr-only"
          tabIndex={-1}
          aria-hidden="true"
        />
        <DialogPrimitive.Close className="absolute right-4 top-4 z-20 rounded-sm opacity-70 ring-offset-background transition-opacity hover:opacity-100 focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2 disabled:pointer-events-none data-[state=open]:bg-accent data-[state=open]:text-muted-foreground">
          <X className="h-4 w-4" />
          <span className="sr-only">Close</span>
        </DialogPrimitive.Close>
      </DialogPrimitive.Content>
    </DialogPortal>
  )
})
DialogContent.displayName = DialogPrimitive.Content.displayName

const DialogHeader = ({
  className,
  ...props
}: React.HTMLAttributes<HTMLDivElement>) => (
  <div
    className={cn(
      "flex flex-col space-y-1.5 text-center sm:text-left",
      className
    )}
    {...props}
  />
)
DialogHeader.displayName = "DialogHeader"

const DialogFooter = ({
  className,
  ...props
}: React.HTMLAttributes<HTMLDivElement>) => (
  <div
    className={cn(
      "flex flex-col-reverse sm:flex-row sm:justify-end sm:space-x-2",
      className
    )}
    {...props}
  />
)
DialogFooter.displayName = "DialogFooter"

const DialogTitle = React.forwardRef<
  React.ElementRef<typeof DialogPrimitive.Title>,
  React.ComponentPropsWithoutRef<typeof DialogPrimitive.Title>
>(({ className, ...props }, ref) => (
  <DialogPrimitive.Title
    ref={ref}
    className={cn(
      "text-lg font-semibold leading-none tracking-tight",
      className
    )}
    {...props}
  />
))
DialogTitle.displayName = DialogPrimitive.Title.displayName

const DialogDescription = React.forwardRef<
  React.ElementRef<typeof DialogPrimitive.Description>,
  React.ComponentPropsWithoutRef<typeof DialogPrimitive.Description>
>(({ className, ...props }, ref) => (
  <DialogPrimitive.Description
    ref={ref}
    className={cn("text-sm text-muted-foreground", className)}
    {...props}
  />
))
DialogDescription.displayName = DialogPrimitive.Description.displayName

export {
  Dialog,
  DialogPortal,
  DialogOverlay,
  DialogClose,
  DialogTrigger,
  DialogContent,
  DialogHeader,
  DialogFooter,
  DialogTitle,
  DialogDescription,
}
