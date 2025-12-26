"use client"

import { AuthScreen } from "@/components/auth/AuthScreen"
import { DashboardLayout } from "@/components/DashboardLayout"
import { useAuth } from "@/context/AuthContext"
import { SocketProvider } from "@/context/SocketContext"

export default function Home() {
  const { status, token, logout } = useAuth()

  if (status === "loading") {
    return (
      <div className="flex min-h-screen w-full items-center justify-center bg-background">
        <div className="text-muted-foreground">Loading...</div>
      </div>
    )
  }

  if (status === "guest") {
    return <AuthScreen />
  }

  return (
    <SocketProvider token={token} onSessionInvalidated={logout}>
      <DashboardLayout />
    </SocketProvider>
  )
}
