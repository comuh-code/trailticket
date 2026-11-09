// Trailticket collector — no dependencies, framework agnostic.
//
//   import * as Trailticket from "trailticket"
//   import { domToJpeg } from "modern-screenshot"            // optional, for screenshots
//
//   Trailticket.start({ endpoint: "/trailticket", screenshot: Trailticket.domScreenshot(domToJpeg) })
//
//   // When the user clicks "report a problem" — BEFORE opening your own modal:
//   const snapshot = await Trailticket.capture()
//   // ...show your form, then:
//   await Trailticket.submit({ title, body, priority }, snapshot)
//
// Mark your report modal with data-trailticket-ignore so it is not recorded,
// and anything that must never leave the browser with data-trailticket-mask.

const TRAIL_KEY = "trailticket:trail"
const MASK = "[FILTERED]"

const DEFAULTS = {
  endpoint: "/trailticket",
  maxTrail: 50,
  maxErrors: 20,
  maxFields: 100,
  maxValueLength: 200,
  captureValues: true,
  // Matched against field names, ids, labels, autocomplete and query params. Do not use the g flag.
  sensitive: /pass|secret|token|card|cvv|cvc|cpf|cnpj|ssn|iban|^otp$|^pin$|cc-|one-time-code/i,
  ignoreSelector: "[data-trailticket-ignore]",
  maskSelector: "[data-trailticket-mask], [data-no-capture]",
  screenshot: null, // async (element) => dataURL
  screenshotElement: () => document.body,
  headers: {},
}

const state = { started: false, options: { ...DEFAULTS }, errors: [] }

// --- Public API --------------------------------------------------------------

export function start(options = {}) {
  state.options = { ...DEFAULTS, ...options }
  if (state.started) return
  state.started = true

  recordVisit()
  document.addEventListener("turbo:load", recordVisit)
  window.addEventListener("popstate", recordVisit)
  patchHistory()

  document.addEventListener("click", onClick, true)
  document.addEventListener("submit", onSubmit, true)
  window.addEventListener("error", onError)
  window.addEventListener("unhandledrejection", onRejection)
}

// Takes a snapshot of where the user is. Call it before opening your form.
export async function capture() {
  if (!state.started) start(state.options)

  const context = {
    page: {
      url: cleanUrl(location.href),
      referrer: document.referrer ? cleanUrl(document.referrer) : "",
      title: document.title,
      user_agent: navigator.userAgent,
      language: navigator.language,
      timezone: safe(() => Intl.DateTimeFormat().resolvedOptions().timeZone, ""),
      viewport: `${window.innerWidth}x${window.innerHeight}`,
      screen: `${window.screen.width}x${window.screen.height}`,
      captured_at: new Date().toISOString(),
    },
    trail: readTrail(),
    fields: captureFields(),
    errors: state.errors.slice(),
  }

  let screenshot = null
  if (state.options.screenshot) {
    try {
      screenshot = await state.options.screenshot(state.options.screenshotElement())
    } catch (error) {
      console.warn("[trailticket] screenshot failed", error)
    }
  }

  return { context, screenshot }
}

// Opens a ticket. fields: { title, body, priority }. snapshot: result of capture().
export async function submit(fields, snapshot) {
  const snap = snapshot || (await capture())
  return request("POST", "/tickets", {
    ticket: { ...fields, context: snap.context, screenshot: snap.screenshot },
  })
}

// Thin client for building your own screens.
export const api = {
  me: () => request("GET", "/me"),
  list: (params = {}) => request("GET", `/tickets?${new URLSearchParams(params)}`),
  get: (id) => request("GET", `/tickets/${id}`),
  update: (id, attrs) => request("PATCH", `/tickets/${id}`, { ticket: attrs }),
  close: (id) => request("POST", `/tickets/${id}/close`),
  reopen: (id) => request("POST", `/tickets/${id}/reopen`),
  reply: (id, body, { internal = false } = {}) =>
    request("POST", `/tickets/${id}/messages`, { message: { body, internal } }),
  screenshotUrl: (id) => `${base()}/tickets/${id}/screenshot`,
}

// Adapter for modern-screenshot (or any lib with the same signature):
//   Trailticket.domScreenshot(domToJpeg, { quality: 0.7 })
// Ignored and sensitive elements are left out of the image.
export function domScreenshot(render, options = {}) {
  return (element) =>
    render(element, {
      quality: 0.7,
      scale: 1,
      ...options,
      filter: (node) => keepInScreenshot(node) && (options.filter ? options.filter(node) : true),
    })
}

export function clearTrail() {
  writeTrail([])
  state.errors = []
}

// --- Trail -------------------------------------------------------------------

function recordVisit() {
  const trail = readTrail()
  const url = cleanUrl(location.href)
  const last = trail[trail.length - 1]
  if (last && last.type === "visit" && last.url === url) return
  push({ type: "visit", label: document.title })
}

function patchHistory() {
  const original = history.pushState
  if (original.__trailticket) return
  const patched = function (...args) {
    const result = original.apply(this, args)
    setTimeout(recordVisit, 0)
    return result
  }
  patched.__trailticket = true
  history.pushState = patched
}

function onClick(event) {
  const target = event.target instanceof Element ? event.target : null
  if (!target || target.closest(state.options.ignoreSelector)) return
  const element =
    target.closest("a, button, input, select, textarea, summary, label, [role='button'], [role='link']") || target
  push({ type: "click", label: describe(element) })
}

function onSubmit(event) {
  const form = event.target
  if (!(form instanceof Element) || form.closest(state.options.ignoreSelector)) return
  push({ type: "submit", label: describe(form) })
}

function push(entry) {
  const trail = readTrail()
  trail.push({ at: new Date().toISOString(), url: cleanUrl(location.href), ...entry })
  writeTrail(trail.slice(-state.options.maxTrail))
}

function describe(element) {
  const tag = element.tagName.toLowerCase()
  const parts = [tag]
  if (element.id) parts.push(`#${element.id}`)
  const testId = element.getAttribute("data-testid")
  if (testId) parts.push(`[data-testid=${testId}]`)
  if (tag === "form") {
    const action = element.getAttribute("action")
    if (action) parts.push(`action=${cleanUrl(action)}`)
    return parts.join(" ")
  }

  let text = ""
  if (!isMasked(element)) {
    const isInput = ["input", "select", "textarea"].includes(tag)
    const isButtonInput = tag === "input" && ["submit", "button"].includes(element.type)
    if (isButtonInput) text = element.value
    else if (isInput) text = element.getAttribute("aria-label") || element.name || ""
    else text = element.getAttribute("aria-label") || textOf(element) || element.getAttribute("title") || ""
  }
  text = text.trim().replace(/\s+/g, " ").slice(0, 60)
  return text ? `${parts.join(" ")} "${text}"` : parts.join(" ")
}

function storage() {
  return safe(() => window.sessionStorage, null)
}

function readTrail() {
  return safe(() => JSON.parse(storage()?.getItem(TRAIL_KEY) || "[]"), [])
}

function writeTrail(trail) {
  safe(() => storage()?.setItem(TRAIL_KEY, JSON.stringify(trail)))
}

// --- Fields ------------------------------------------------------------------

function captureFields(root = document) {
  const o = state.options
  const fields = []
  for (const el of root.querySelectorAll("input, select, textarea")) {
    if (fields.length >= o.maxFields) break
    if (el.closest(o.ignoreSelector)) continue

    const type = (el.type || el.tagName).toLowerCase()
    if (["hidden", "submit", "button", "reset", "image", "file"].includes(type)) continue

    let value
    if (type === "checkbox" || type === "radio") {
      if (!el.checked) continue
      value = el.value === "on" ? "true" : el.value
    } else if (el.tagName === "SELECT" && el.multiple) {
      value = Array.from(el.selectedOptions, (option) => option.value).join(", ")
    } else {
      value = el.value
    }
    if (value == null || value === "") continue

    const masked = isSensitive(el)
    const field = { name: el.name || el.id || "", label: labelFor(el), type, masked }
    if (masked) field.value = MASK
    else if (o.captureValues) field.value = String(value).slice(0, o.maxValueLength)
    fields.push(field)
  }
  return fields
}

function labelFor(el) {
  const text = textOf(el.labels?.[0]) || el.getAttribute("aria-label") || el.getAttribute("placeholder") || ""
  return text.trim().replace(/\s+/g, " ").slice(0, 80)
}

function isMasked(el) {
  return !!el.closest(state.options.maskSelector)
}

function isSensitive(el) {
  if (el.type === "password" || isMasked(el)) return true
  const re = state.options.sensitive
  return [el.name, el.id, el.getAttribute("autocomplete"), labelFor(el)].some((text) => text && re.test(text))
}

function keepInScreenshot(node) {
  if (!(node instanceof Element)) return true
  if (node.matches(state.options.ignoreSelector) || node.matches(state.options.maskSelector)) return false
  if (node.matches("input, textarea, select") && isSensitive(node)) return false
  return true
}

// --- Errors ------------------------------------------------------------------

function onError(event) {
  recordError({
    type: "error",
    message: event.message || String(event.error || "Error"),
    source: event.filename ? cleanUrl(event.filename) : "",
    line: event.lineno,
    column: event.colno,
    stack: event.error?.stack || "",
  })
}

function onRejection(event) {
  const reason = event.reason
  recordError({
    type: "unhandledrejection",
    message: reason?.message || String(reason),
    stack: reason?.stack || "",
  })
}

function recordError(error) {
  state.errors.push({ at: new Date().toISOString(), ...error })
  state.errors = state.errors.slice(-state.options.maxErrors)
}

// --- Helpers -----------------------------------------------------------------

function cleanUrl(href) {
  try {
    const url = new URL(href, location.href)
    for (const key of Array.from(url.searchParams.keys())) {
      if (state.options.sensitive.test(key)) url.searchParams.set(key, MASK)
    }
    return url.toString()
  } catch {
    return String(href).split("?")[0]
  }
}

function base() {
  return state.options.endpoint.replace(/\/$/, "")
}

async function request(method, path, body) {
  const headers = { Accept: "application/json", ...state.options.headers }
  if (body) headers["Content-Type"] = "application/json"
  const token = document.querySelector('meta[name="csrf-token"]')?.content
  if (token) headers["X-CSRF-Token"] = token

  const response = await fetch(base() + path, {
    method,
    headers,
    credentials: "same-origin",
    body: body ? JSON.stringify(body) : undefined,
  })
  const data = await response.json().catch(() => ({}))
  if (!response.ok) {
    const error = new Error(data.error || `HTTP ${response.status}`)
    error.status = response.status
    error.data = data
    throw error
  }
  return data
}

function textOf(element) {
  if (!element) return ""
  return element.innerText ?? element.textContent ?? ""
}

function safe(fn, fallback) {
  try {
    return fn()
  } catch {
    return fallback
  }
}
