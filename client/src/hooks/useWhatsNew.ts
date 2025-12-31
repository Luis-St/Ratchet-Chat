"use client"

import { useState, useEffect, useCallback } from "react"

const SEEN_VERSION_KEY = "ratchet-seen-version"
const appVersion = process.env.NEXT_PUBLIC_APP_VERSION ?? "unknown"

export function useWhatsNew() {
  const [hasNewVersion, setHasNewVersion] = useState(false)

  useEffect(() => {
    if (appVersion === "unknown") {
      return
    }

    try {
      const seenVersion = localStorage.getItem(SEEN_VERSION_KEY)
      if (!seenVersion || seenVersion !== appVersion) {
        setHasNewVersion(true)
      }
    } catch {
      // localStorage might not be available
    }
  }, [])

  const markAsSeen = useCallback(() => {
    if (appVersion === "unknown") {
      return
    }

    try {
      localStorage.setItem(SEEN_VERSION_KEY, appVersion)
      setHasNewVersion(false)
    } catch {
      // localStorage might not be available
    }
  }, [])

  return {
    hasNewVersion,
    markAsSeen,
    currentVersion: appVersion,
  }
}
