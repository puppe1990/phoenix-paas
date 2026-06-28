function bindPasswordToggle(button) {
  if (button.dataset.passwordToggleBound) return

  button.dataset.passwordToggleBound = "true"

  const field = button.closest("[data-password-field]")
  const input = field?.querySelector("input")
  const showIcon = button.querySelector('[data-password-icon="show"]')
  const hideIcon = button.querySelector('[data-password-icon="hide"]')

  if (!input || !showIcon || !hideIcon) return

  button.addEventListener("click", () => {
    const revealing = input.type === "password"

    input.type = revealing ? "text" : "password"
    button.setAttribute("aria-pressed", revealing ? "true" : "false")
    button.setAttribute("aria-label", revealing ? "Hide password" : "Show password")
    showIcon.classList.toggle("hidden", revealing)
    hideIcon.classList.toggle("hidden", !revealing)
  })
}

export function initPasswordToggles(root = document) {
  root.querySelectorAll("[data-password-toggle]").forEach(bindPasswordToggle)
}