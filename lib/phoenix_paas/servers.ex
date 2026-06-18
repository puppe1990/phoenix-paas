defmodule PhoenixPaas.Servers do
  @moduledoc """
  Manages deploy target servers (Lightsail VMs).
  """

  import Ecto.Query, warn: false
  alias PhoenixPaas.Repo
  alias PhoenixPaas.Servers.Server

  def list_servers do
    Repo.all(from s in Server, order_by: [asc: s.name])
  end

  def get_server!(id), do: Repo.get!(Server, id)

  def create_server(attrs) do
    %Server{}
    |> Server.changeset(attrs)
    |> Repo.insert()
  end

  def change_server(server, attrs \\ %{}) do
    Server.changeset(server, attrs)
  end
end
