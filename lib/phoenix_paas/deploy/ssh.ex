defmodule PhoenixPaas.Deploy.Ssh do
  @moduledoc false

  @tar_excludes ~w(_build deps node_modules .git tmp priv/static/assets)

  def run_deploy(deployment, app, server) do
    config = PhoenixPaas.Apps.App.deploy_config(app)
    branch = deployment.git_ref || app.branch
    sha = short_sha(deployment.git_sha)

    key_path = nil
    work_dir = nil
    tarball = nil

    with :ok <- ensure_commands(["git", "ssh", "scp", "tar"]) do
      try do
        with {:ok, key_path} <- write_temp_key(server),
             {:ok, work_dir} <- clone_repo(app.github_repo, branch),
             {:ok, tarball} <- create_tarball(work_dir),
             {:ok, log} <- upload_and_build(tarball, key_path, server, app, config, sha) do
          {:ok, log}
        end
      after
        cleanup(key_path, work_dir, tarball)
      end
    end
  end

  defp ensure_commands(commands) do
    missing =
      Enum.reject(commands, fn cmd ->
        case System.find_executable(cmd) do
          nil -> false
          _ -> true
        end
      end)

    if missing == [] do
      :ok
    else
      {:error, "Missing commands: #{Enum.join(missing, ", ")}"}
    end
  end

  defp write_temp_key(%{ssh_private_key_encrypted: key}) when key in [nil, ""],
    do: {:error, "SSH private key not configured on server"}

  defp write_temp_key(%{ssh_private_key_encrypted: key}) do
    path = Path.join(System.tmp_dir!(), "phoenix_paas_ssh_#{:erlang.unique_integer([:positive])}")

    with :ok <- File.write(path, key),
         :ok <- File.chmod(path, 0o600) do
      {:ok, path}
    else
      {:error, reason} -> {:error, "Could not write SSH key: #{inspect(reason)}"}
    end
  end

  defp clone_repo(github_repo, branch) do
    dir =
      Path.join(System.tmp_dir!(), "phoenix_paas_clone_#{:erlang.unique_integer([:positive])}")

    url = github_clone_url(github_repo)

    case cmd("git", ["clone", "--depth", "50", "-b", branch, url, dir]) do
      {:ok, _output} -> {:ok, dir}
      {:error, output} -> {:error, "git clone failed:\n#{output}"}
    end
  end

  defp create_tarball(work_dir) do
    path =
      Path.join(
        System.tmp_dir!(),
        "phoenix_paas_src_#{:erlang.unique_integer([:positive])}.tar.gz"
      )

    args = ["-czf", path] ++ tar_exclude_args() ++ ["-C", work_dir, "."]

    case cmd("tar", args) do
      {:ok, _output} -> {:ok, path}
      {:error, output} -> {:error, "tar failed:\n#{output}"}
    end
  end

  defp upload_and_build(tarball, key_path, server, app, config, sha) do
    remote_tar = "/tmp/phoenix_paas_#{sha}.tar.gz"
    target = "#{server.ssh_user}@#{server.host_ip}"

    with {:ok, upload_out} <- scp(tarball, remote_tar, key_path, target),
         {:ok, build_out} <- remote_build(remote_tar, key_path, target, server, config, sha) do
      log =
        [
          "==> Cloning #{app.github_repo} (branch #{app.branch})",
          "==> Uploading source to #{target}",
          trim(upload_out),
          "==> Building OTP release on Lightsail VM",
          trim(build_out),
          "==> Deployment successful — live at https://#{app.host}"
        ]
        |> Enum.reject(&(&1 == ""))
        |> Enum.join("\n")

      {:ok, log}
    end
  end

  defp scp(local, remote, key_path, target) do
    case cmd("scp", scp_base(key_path) ++ [local, "#{target}:#{remote}"]) do
      {:ok, output} -> {:ok, output}
      {:error, output} -> {:error, "scp failed:\n#{output}"}
    end
  end

  defp remote_build(remote_tar, key_path, target, server, config, sha) do
    script = remote_build_script(server, config, sha, remote_tar)
    script_path = Path.join(System.tmp_dir!(), "phoenix_paas_remote_#{sha}.sh")

    try do
      :ok = File.write!(script_path, script)

      ssh_args =
        (ssh_base(key_path, target) ++ ["bash", "-s"])
        |> Enum.map(&shell_escape/1)
        |> Enum.join(" ")

      case System.cmd("bash", ["-c", "ssh #{ssh_args} < #{shell_escape(script_path)}"],
             stderr_to_stdout: true
           ) do
        {output, 0} -> {:ok, output}
        {output, _code} -> {:error, "remote build failed:\n#{output}"}
      end
    after
      File.rm(script_path)
    end
  end

  defp shell_escape(value) when is_binary(value) do
    "'" <> String.replace(value, "'", "'\\''") <> "'"
  end

  defp remote_build_script(server, config, sha, remote_tar) do
    """
    set -euo pipefail

    log() { printf '==> %s\\n' "$*"; }

    if ! swapon --show | grep -q /swapfile; then
      sudo fallocate -l 2G /swapfile || true
      sudo chmod 600 /swapfile || true
      sudo mkswap /swapfile || true
      sudo swapon /swapfile || true
    fi

    if ! command -v mise >/dev/null 2>&1; then
      log "Installing mise + Erlang/Elixir"
      sudo apt-get update
      sudo apt-get install -y curl build-essential git ca-certificates
      curl -fsSL https://mise.run | sh
    fi

    export PATH="/home/#{server.ssh_user}/.local/bin:$PATH"
    eval "$(/home/#{server.ssh_user}/.local/bin/mise activate bash)"
    mise install erlang@28.4.1 elixir@1.19.5-otp-28
    mise use -g erlang@28.4.1 elixir@1.19.5-otp-28

    BUILD_DIR="$HOME/phoenix_paas_build_#{sha}"
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    tar -xzf #{remote_tar} -C "$BUILD_DIR"
    cd "$BUILD_DIR"

    export MIX_ENV=prod
    export SECRET_KEY_BASE=buildtime_secret_key_base_32chars_min
    export TURSO_DATABASE_URL=libsql://build.turso.io

    log "Fetching dependencies"
    mix local.hex --force
    mix local.rebar --force
    mix deps.get --only prod

    log "Compiling application"
    mix compile

    log "Compiling assets"
    mix assets.setup
    mix assets.deploy

    log "Building release #{config.release_name}"
    mix release

    RELEASE_DIR="#{config.release_path}/releases/build"
    sudo mkdir -p "$RELEASE_DIR"
    sudo rm -rf "${RELEASE_DIR:?}"/*
    sudo cp -a "_build/prod/rel/#{config.release_name}/." "$RELEASE_DIR/"
    sudo ln -sfn "$RELEASE_DIR" #{config.release_path}/current

    if [[ -f #{config.env_file} ]]; then
      log "Running migrations"
      sudo bash -c 'set -a; source #{config.env_file}; set +a; #{config.release_path}/current/bin/migrate'
    else
      log "No #{config.env_file} — skipping migrations"
    fi

    log "Restarting #{config.systemd_unit}"
    sudo systemctl restart #{config.systemd_unit}
    sleep 2

    if sudo systemctl is-active --quiet #{config.systemd_unit}; then
      log "Service #{config.systemd_unit} is active"
    else
      sudo journalctl -u #{config.systemd_unit} -n 30 --no-pager
      exit 1
    fi
    """
  end

  defp github_clone_url(repo) do
    case System.get_env("GITHUB_TOKEN") do
      token when is_binary(token) and token != "" ->
        "https://x-access-token:#{token}@github.com/#{repo}.git"

      _ ->
        "https://github.com/#{repo}.git"
    end
  end

  defp short_sha("manual"), do: Integer.to_string(System.system_time(:second))
  defp short_sha(sha) when is_binary(sha), do: String.slice(sha, 0, 7)

  defp tar_exclude_args do
    Enum.flat_map(@tar_excludes, fn entry -> ["--exclude", entry] end)
  end

  defp ssh_base(key_path, target) do
    [
      "-i",
      key_path,
      "-o",
      "StrictHostKeyChecking=accept-new",
      "-o",
      "BatchMode=yes",
      "-o",
      "ServerAliveInterval=30",
      "-o",
      "ServerAliveCountMax=120",
      target
    ]
  end

  defp scp_base(key_path) do
    [
      "-i",
      key_path,
      "-o",
      "StrictHostKeyChecking=accept-new",
      "-o",
      "BatchMode=yes",
      "-o",
      "ServerAliveInterval=30",
      "-o",
      "ServerAliveCountMax=120"
    ]
  end

  defp cmd(command, args) do
    case System.cmd(command, args, stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {output, _code} -> {:error, output}
    end
  end

  defp trim(value) when is_binary(value), do: String.trim(value)
  defp trim(_), do: ""

  defp cleanup(key_path, work_dir, tarball) do
    if is_binary(key_path), do: File.rm(key_path)
    if is_binary(work_dir), do: File.rm_rf(work_dir)
    if is_binary(tarball), do: File.rm(tarball)
  end
end
