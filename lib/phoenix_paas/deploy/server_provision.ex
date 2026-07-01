defmodule PhoenixPaas.Deploy.ServerProvision do
  @moduledoc false

  alias PhoenixPaas.Apps.App
  alias PhoenixPaas.Deploy.AppManifest

  @doc false
  def provision_script(%App{} = app, config, %AppManifest{} = manifest) do
    data_dir = "/var/lib/#{Path.basename(config.release_path)}"
    env_dir = Path.dirname(config.env_file)
    memory_max = manifest.memory_max_mb || 400

    unit = """
    [Unit]
    Description=#{escape_unit_description(app.name)}
    After=network.target

    [Service]
    Type=exec
    User=root
    Group=root
    WorkingDirectory=#{config.release_path}/current
    EnvironmentFile=#{config.env_file}
    ExecStart=#{config.release_path}/current/bin/#{config.release_name} start
    Restart=always
    RestartSec=5
    MemoryMax=#{memory_max}M
    LimitNOFILE=65535

    [Install]
    WantedBy=multi-user.target
    """

    caddy_script = caddy_provision_script(app, manifest)

    """
    log "Provisioning host #{app.host} on port #{app.port}"
    sudo mkdir -p #{shell_escape(env_dir)} #{shell_escape(data_dir)}

    sudo tee /etc/systemd/system/#{config.systemd_unit}.service > /dev/null <<'PAAS_SYSTEMD_UNIT'
    #{String.trim_trailing(unit)}
    PAAS_SYSTEMD_UNIT

    sudo systemctl daemon-reload
    sudo systemctl enable #{config.systemd_unit}

    #{caddy_script}
    """
  end

  defp caddy_provision_script(%App{}, %AppManifest{caddy_mode: "replace", caddyfile: path})
       when is_binary(path) and path != "" do
    """
    log "Installing custom Caddyfile (#{path})"
    if [[ ! -f "$BUILD_DIR/#{path}" ]]; then
      echo "Custom Caddyfile not found at $BUILD_DIR/#{path}" >&2
      exit 1
    fi
    sudo cp "$BUILD_DIR/#{path}" /etc/caddy/Caddyfile
    """
  end

  defp caddy_provision_script(%App{} = app, %AppManifest{}) do
    caddy_site = """

    #{app.host} {
      encode gzip
      reverse_proxy 127.0.0.1:#{app.port}
    }
    """

    """
    if ! sudo grep -Fq '#{app.host} {' /etc/caddy/Caddyfile; then
      log "Adding Caddy site #{app.host}"
      sudo tee -a /etc/caddy/Caddyfile > /dev/null <<'PAAS_CADDY_SITE'
    #{String.trim_leading(caddy_site)}
    PAAS_CADDY_SITE
    fi
    """
  end

  @doc false
  def migrate_script(config) do
    release_bin = "#{config.release_path}/current/bin/#{config.release_name}"
    otp_app = config.release_name

    """
    if [[ -f #{config.env_file} ]]; then
      if [[ -x #{config.release_path}/current/bin/migrate ]]; then
        log "Running migrations (bin/migrate)"
        sudo bash -c 'set -a; source #{config.env_file}; set +a; #{config.release_path}/current/bin/migrate'
      elif [[ -x #{release_bin} ]]; then
        log "Running migrations (release eval)"
        sudo bash -c 'set -a; source #{config.env_file}; set +a; #{release_bin} eval "#{migration_eval(otp_app)}"'
      else
        log "Skipping migrations (no migrate command)"
      fi
    else
      log "Skipping migrations (env file missing)"
    fi
    """
  end

  @doc false
  def reload_caddy_script do
    """
    log "Reloading Caddy (TLS/DNS catch-up)"
    sudo systemctl reload caddy 2>/dev/null || sudo systemctl restart caddy
    """
  end

  defp migration_eval(otp_app) when is_binary(otp_app) do
    """
    Application.load(:#{otp_app}); case Application.get_env(:#{otp_app}, :ecto_repos, []) do [] -> :ok; repos -> for repo <- repos, do: {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true)) end
    """
    |> String.trim()
  end

  defp escape_unit_description(name) when is_binary(name) do
    name |> String.replace(~r/[\r\n]/, " ") |> String.trim()
  end

  defp shell_escape(path) when is_binary(path) do
    "'" <> String.replace(path, "'", "'\\''") <> "'"
  end
end
