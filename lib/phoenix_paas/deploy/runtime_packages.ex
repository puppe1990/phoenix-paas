defmodule PhoenixPaas.Deploy.RuntimePackages do
  @moduledoc false

  alias PhoenixPaas.Apps.App

  @manifest ".phoenix_paas/runtime-packages"
  @post_install ".phoenix_paas/post-install.sh"

  @rapid_tools_post_install [
    "if [[ -f /etc/ImageMagick-6/policy.xml ]]; then",
    ~s(sed -i 's/<policy domain="coder" rights="none" pattern="PDF"/<policy domain="coder" rights="read|write" pattern="PDF"/' /etc/ImageMagick-6/policy.xml || true),
    "fi"
  ]

  @slug_profiles %{
    "rapid-tools" => %{
      packages: ~w(ffmpeg imagemagick ghostscript zip unzip),
      post_install: @rapid_tools_post_install
    }
  }

  def resolve(%App{} = app, repo_path \\ nil) do
    packages =
      (slug_packages(app.slug) ++
         List.wrap(app.runtime_apt_packages) ++ from_repo_manifest(repo_path))
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    post_install =
      (slug_post_install(app.slug) ++ from_repo_post_install(repo_path))
      |> Enum.reject(&(&1 == ""))

    %{packages: packages, post_install: post_install}
  end

  defp slug_packages(slug), do: Map.get(@slug_profiles, slug, %{}) |> Map.get(:packages, [])

  defp slug_post_install(slug),
    do: Map.get(@slug_profiles, slug, %{}) |> Map.get(:post_install, [])

  defp from_repo_manifest(nil), do: []

  defp from_repo_manifest(repo_path) do
    path = Path.join(repo_path, @manifest)

    if File.exists?(path) do
      path |> File.read!() |> parse_lines()
    else
      []
    end
  end

  defp from_repo_post_install(nil), do: []

  defp from_repo_post_install(repo_path) do
    path = Path.join(repo_path, @post_install)

    if File.exists?(path) do
      path |> File.read!() |> String.split("\n", trim: false)
    else
      []
    end
  end

  defp parse_lines(content) do
    content
    |> String.split(~r/[\r\n]+/, trim: true)
    |> Enum.flat_map(&String.split(&1, ~r/\s+/, trim: true))
    |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
  end
end
