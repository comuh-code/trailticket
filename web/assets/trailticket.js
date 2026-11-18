// Trailticket web interface: drag cards between board columns.
// Native HTML5 drag and drop, no dependencies. Without JS (or on touch screens),
// the status buttons on the ticket page do the same thing.
(() => {
  "use strict"

  const board = document.querySelector("[data-tt-board]")
  if (!board) return

  const flash = document.querySelector("[data-tt-flash]")
  let dragged = null
  let flashTimer = null

  const columnOf = (node) => node && node.closest && node.closest("[data-tt-column]")
  const listOf = (column) => column.querySelector("[data-tt-cards]")

  function refresh(column, delta) {
    const counter = column.querySelector("[data-tt-count]")
    if (counter) counter.textContent = String(Math.max(0, Number(counter.textContent) + delta))
    const empty = column.querySelector("[data-tt-empty]")
    if (empty) empty.hidden = listOf(column).children.length > 0
  }

  function showError(message) {
    if (!flash) return
    flash.textContent = message // textContent: never interpreted as HTML
    flash.hidden = false
    clearTimeout(flashTimer)
    flashTimer = setTimeout(() => { flash.hidden = true }, 6000)
  }

  function clearHighlight() {
    board.querySelectorAll(".is-over").forEach((column) => column.classList.remove("is-over"))
  }

  board.addEventListener("dragstart", (event) => {
    const card = event.target.closest && event.target.closest("[data-tt-card]")
    if (!card) return
    dragged = card
    card.classList.add("is-dragging")
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", card.dataset.id)
  })

  board.addEventListener("dragend", () => {
    if (dragged) dragged.classList.remove("is-dragging")
    dragged = null
    clearHighlight()
  })

  board.addEventListener("dragover", (event) => {
    const column = columnOf(event.target)
    if (!dragged || !column) return
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
    if (!column.classList.contains("is-over")) {
      clearHighlight()
      column.classList.add("is-over")
    }
  })

  board.addEventListener("dragleave", (event) => {
    const column = columnOf(event.target)
    if (column && !column.contains(event.relatedTarget)) column.classList.remove("is-over")
  })

  board.addEventListener("drop", async (event) => {
    const to = columnOf(event.target)
    if (!dragged || !to) return
    event.preventDefault()
    clearHighlight()

    const card = dragged
    const from = columnOf(card)
    if (from === to) return

    const next = card.nextElementSibling
    listOf(to).prepend(card)
    refresh(from, -1)
    refresh(to, +1)
    card.classList.add("is-saving")

    try {
      const token = document.querySelector('meta[name="csrf-token"]')
      const response = await fetch(card.dataset.url, {
        method: "PATCH",
        credentials: "same-origin",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          ...(token ? { "X-CSRF-Token": token.content } : {}),
        },
        body: JSON.stringify({ status: to.dataset.status }),
      })
      const data = await response.json().catch(() => ({}))
      if (!response.ok) throw new Error(data.error || `HTTP ${response.status}`)
      card.dataset.status = data.status
    } catch (error) {
      const list = listOf(from)
      list.insertBefore(card, next && next.parentNode === list ? next : null)
      refresh(to, -1)
      refresh(from, +1)
      showError(`${board.dataset.error} ${error.message}`)
    } finally {
      card.classList.remove("is-saving")
    }
  })
})()
