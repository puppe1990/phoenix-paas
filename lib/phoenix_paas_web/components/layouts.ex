defmodule PhoenixPaasWeb.Layouts do
  @moduledoc """
  Layouts for Phoenix PaaS control panel.
  """
  use PhoenixPaasWeb, :html

  embed_templates "layouts/*"

  attr :flash, :map, required: true
  attr :active_tab, :atom, required: true
  attr :browser_path, :string, default: "dashboard"
  attr :server_count, :integer, default: 0
  attr :app_count, :integer, default: 0

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <PaasShell.shell
      flash={@flash}
      active_tab={@active_tab}
      browser_path={@browser_path}
      server_count={@server_count}
      app_count={@app_count}
    >
      {render_slot(@inner_block)}
    </PaasShell.shell>
    """
  end
end
