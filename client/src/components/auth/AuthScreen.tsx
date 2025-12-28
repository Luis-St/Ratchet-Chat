"use client"

import * as React from "react"
import { useForm } from "react-hook-form"
import { Fingerprint, Key, Lock, User } from "lucide-react"

import { useAuth } from "@/context/AuthContext"
import { getInstanceHost, normalizeHandle, splitHandle } from "@/lib/handles"
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
import { ScrollArea } from "@/components/ui/scroll-area"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Label } from "@/components/ui/label"
import { Switch } from "@/components/ui/switch"

type RegisterValues = {
  username: string
  password: string
  confirmPassword: string
}

export function AuthScreen() {
  const { register: registerUser, loginWithPasskey } = useAuth()
  const [authError, setAuthError] = React.useState<string | null>(null)
  const [loading, setLoading] = React.useState<"login" | "register" | null>(null)
  const [savePassword, setSavePassword] = React.useState(false)
  const instanceHost = getInstanceHost()

  const validateLocalHandle = React.useCallback(
    (value: string) => {
      const trimmed = value.trim()
      if (!trimmed) {
        return "Username is required"
      }
      if (!trimmed.includes("@")) {
        return true
      }
      const parts = splitHandle(trimmed)
      if (!parts) {
        return "Enter a valid handle like alice@host"
      }
      if (!instanceHost) {
        return "Instance host is not configured"
      }
      if (parts.host !== instanceHost) {
        return "Use a local username only"
      }
      return true
    },
    [instanceHost]
  )

  const registerForm = useForm<RegisterValues>({
    defaultValues: { username: "", password: "", confirmPassword: "" },
  })

  const handleLogin = React.useCallback(async () => {
    setAuthError(null)
    setLoading("login")
    try {
      await loginWithPasskey()
    } catch (error) {
      const message = error instanceof Error ? error.message : "Unable to login"
      // Handle user cancellation gracefully
      if (message.includes("cancelled") || message.includes("canceled") || message.includes("abort")) {
        setAuthError(null)
      } else {
        setAuthError(message)
      }
    } finally {
      setLoading(null)
    }
  }, [loginWithPasskey])

  const handleRegister = React.useCallback(
    async (values: RegisterValues) => {
      setAuthError(null)
      if (values.password !== values.confirmPassword) {
        setAuthError("Passwords do not match")
        return
      }
      setLoading("register")
      try {
        await registerUser(values.username, values.password, savePassword)
      } catch (error) {
        const message = error instanceof Error ? error.message : "Unable to register"
        // Handle user cancellation gracefully
        if (message.includes("cancelled") || message.includes("canceled") || message.includes("abort")) {
          setAuthError(null)
        } else {
          setAuthError(message)
        }
      } finally {
        setLoading(null)
      }
    },
    [registerUser, savePassword]
  )

  return (
    <div className="flex min-h-screen w-full items-center justify-center bg-background p-6">
      <Card className="w-full max-w-lg border-border bg-card/90 shadow-xl backdrop-blur">
        <CardHeader>
          <CardTitle className="text-2xl">Ratchet-Chat</CardTitle>
          <CardDescription>
            Zero-knowledge access. Keys stay in your browser.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <Tabs defaultValue="login" className="w-full">
            <TabsList className="grid w-full grid-cols-2">
              <TabsTrigger value="login">Login</TabsTrigger>
              <TabsTrigger value="register">Register</TabsTrigger>
            </TabsList>
            <TabsContent value="login" className="space-y-4">
              <div className="text-sm text-muted-foreground">
                Use your passkey to sign in. Your browser will prompt you to authenticate.
              </div>
              {authError ? (
                <p className="text-destructive text-sm">{authError}</p>
              ) : null}
              <Button
                onClick={handleLogin}
                className="w-full"
                disabled={loading === "login"}
              >
                <Fingerprint className="mr-2 h-4 w-4" />
                {loading === "login" ? "Authenticating..." : "Sign in with Passkey"}
              </Button>
            </TabsContent>
            <TabsContent value="register">
              <Form {...registerForm}>
                <form
                  onSubmit={registerForm.handleSubmit(handleRegister)}
                  className="space-y-4"
                >
                  <FormField
                    control={registerForm.control}
                    name="username"
                    rules={{
                      required: "Username is required",
                      validate: validateLocalHandle,
                    }}
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Username</FormLabel>
                        <FormControl>
                          <Input
                            autoComplete="username"
                            placeholder="alice"
                            {...field}
                          />
                        </FormControl>
                        {instanceHost ? (
                          <p className="text-xs text-muted-foreground">
                            Handle: {normalizeHandle(field.value || "alice")}
                          </p>
                        ) : null}
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                  <FormField
                    control={registerForm.control}
                    name="password"
                    rules={{
                      required: "Password is required",
                      minLength: {
                        value: 12,
                        message: "Password must be at least 12 characters",
                      },
                    }}
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Master Password</FormLabel>
                        <FormControl>
                          <Input
                            type="password"
                            autoComplete="new-password"
                            placeholder="minimum 12 characters"
                            {...field}
                          />
                        </FormControl>
                        <p className="text-xs text-muted-foreground">
                          Used to encrypt your private keys. Choose a strong, unique password.
                        </p>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                  <FormField
                    control={registerForm.control}
                    name="confirmPassword"
                    rules={{
                      required: "Please confirm your password",
                      validate: (value) =>
                        value === registerForm.watch("password") || "Passwords do not match",
                    }}
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Confirm Password</FormLabel>
                        <FormControl>
                          <Input
                            type="password"
                            autoComplete="new-password"
                            placeholder="confirm your password"
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
                  {!savePassword && (
                    <p className="text-xs text-muted-foreground">
                      You&apos;ll need to enter your password each time you sign in.
                    </p>
                  )}
                  {authError ? (
                    <p className="text-destructive text-sm">{authError}</p>
                  ) : null}
                  <Button type="submit" className="w-full" disabled={loading === "register"}>
                    <Key className="mr-2 h-4 w-4" />
                    {loading === "register" ? "Creating passkey..." : "Create Account with Passkey"}
                  </Button>
                </form>
              </Form>
            </TabsContent>
          </Tabs>
          <ScrollArea className="h-28 rounded-md border border-border bg-muted/70 p-3 text-xs text-muted-foreground">
            <div className="grid gap-2">
              <div className="flex items-center gap-2">
                <Fingerprint className="h-3.5 w-3.5" />
                <span>Passkeys provide phishing-resistant authentication.</span>
              </div>
              <div className="flex items-center gap-2">
                <Lock className="h-3.5 w-3.5" />
                <span>Master password encrypts keys locally; never transmitted.</span>
              </div>
              <div className="flex items-center gap-2">
                <User className="h-3.5 w-3.5" />
                <span>Private keys stay encrypted at rest on your device.</span>
              </div>
            </div>
          </ScrollArea>
        </CardContent>
      </Card>
    </div>
  )
}
