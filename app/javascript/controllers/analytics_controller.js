import { Controller } from "@hotwired/stimulus"

// Fires server-confirmed Plausible conversion goals. A hidden element carries
// data-analytics-goals-value (a JSON array of "Goal" strings or [ "Goal",
// { props } ] pairs) queued in flash[:goals] by ApplicationController#track_goal.
// Firing on connect (i.e. after the post-action redirect) means a goal only
// counts once the server actually committed the action. Plausible only loads in
// production, so #send no-ops gracefully everywhere else.
export default class extends Controller {
  static values = { goals: { type: Array, default: [] } }

  connect() {
    this.goalsValue.forEach((goal) => {
      Array.isArray(goal) ? this.#send(goal[0], goal[1]) : this.#send(goal)
    })
  }

  #send(name, props) {
    if (typeof window.plausible !== "function") return
    window.plausible(name, props ? { props } : undefined)
  }
}
