"use client"

import * as React from "react"
import { useForm } from "react-hook-form"
import { Lock, LogOut } from "lucide-react"

import { useAuth } from "@/context/AuthContext"
import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Switch } from "@/components/ui/switch"

type UnlockValues = {
  password: string
}

export function LockScreen() {
  const { user, unlock, logout } = useAuth()
  const [error, setError] = React.useState<string | null>(null)
  const [loading, setLoading] = React.useState(false)
  const [savePassword, setSavePassword] = React.useState(false)

  const form = useForm<UnlockValues>({
    defaultValues: { password: "" },
  })

  const handleUnlock = React.useCallback(
    async (values: UnlockValues) => {
      setError(null)
      setLoading(true)
      try {
        await unlock(values.password, savePassword)
      } catch (err) {
        const message = err instanceof Error ? err.message : "Unable to unlock"
        setError(message)
      } finally {
        setLoading(false)
      }
    },
    [unlock, savePassword]
  )

  const handleLogout = React.useCallback(() => {
    logout()
  }, [logout])

  return (
    <div className="flex min-h-screen w-full items-center justify-center bg-background p-6">
      <Card className="w-full max-w-md border-border bg-card/90 shadow-xl backdrop-blur">
        <CardHeader className="text-center">
          <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-muted">
            <Lock className="h-8 w-8 text-muted-foreground" />
          </div>
          <CardTitle className="text-2xl">Welcome back</CardTitle>
          <CardDescription>
            {user?.username ? (
              <>Signed in as <span className="font-medium text-foreground">{user.username}</span></>
            ) : (
              "Enter your password to unlock"
            )}
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <Form {...form}>
            <form onSubmit={form.handleSubmit(handleUnlock)} className="space-y-4">
              <FormField
                control={form.control}
                name="password"
                rules={{ required: "Password is required" }}
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Master Password</FormLabel>
                    <FormControl>
                      <Input
                        type="password"
                        autoComplete="current-password"
                        placeholder="Enter your password"
                        autoFocus
                        {...field}
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              <div className="flex items-center space-x-2">
                <Switch
                  id="save-password"
                  checked={savePassword}
                  onCheckedChange={setSavePassword}
                />
                <Label htmlFor="save-password" className="text-sm">
                  Remember password on this device
                </Label>
              </div>
              {error ? (
                <p className="text-destructive text-sm">{error}</p>
              ) : null}
              <Button type="submit" className="w-full" disabled={loading}>
                {loading ? "Unlocking..." : "Unlock"}
              </Button>
            </form>
          </Form>
          <div className="relative">
            <div className="absolute inset-0 flex items-center">
              <span className="w-full border-t" />
            </div>
            <div className="relative flex justify-center text-xs uppercase">
              <span className="bg-card px-2 text-muted-foreground">or</span>
            </div>
          </div>
          <Button
            variant="outline"
            className="w-full"
            onClick={handleLogout}
          >
            <LogOut className="mr-2 h-4 w-4" />
            Sign out
          </Button>
          <p className="text-center text-xs text-muted-foreground">
            Your private keys are encrypted with your master password.
            Enter it to decrypt and access your messages.
          </p>
        </CardContent>
      </Card>
    </div>
  )
}
