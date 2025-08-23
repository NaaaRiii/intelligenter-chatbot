import { Application } from "@hotwired/stimulus"

// 最低限の ActionCable 代替型（テスト/ラッパー用途）
export interface SubscriptionLike {
  identifier?: string
  received?: (data: unknown) => void
  perform?: (action: string, params?: unknown) => void
}

export interface AppSubscriptions {
  list?: SubscriptionLike[]
  push?: (sub: SubscriptionLike) => void
  find?: (predicate: (s: SubscriptionLike) => boolean) => SubscriptionLike | undefined
}

export interface AppCable {
  subscriptions?: AppSubscriptions
  connect?: () => void
  disconnect?: () => void
}

export interface AppGlobal {
  cable?: AppCable
  forceRest?: boolean
}

declare global {
  interface Window {
    Stimulus: Application
    App?: AppGlobal
    __SUPPRESS_TYPING_HIDE_UNTIL?: number
  }
}

export {}
