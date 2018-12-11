defmodule Bonny do
  @moduledoc """
  Documentation for Bonny.
  """

  @doc """
  The namespace to watch for `Namespaced` CRDs.
  """
  @spec namespace() :: String.t()
  def namespace() do
    Application.get_env(:bonny, :override_namespace) || System.get_env("BONNY_POD_NAMESPACE") ||
      "default"
  end

  @doc """
  `K8s.Conf` configuration. This is used to sign HTTP requests to the Kubernetes API.

  Bonny defaults to the service account of the pod if a cluster configuration is not provided.
  """
  def kubeconfig() do
    case config_path() do
      conf_path when is_binary(conf_path) ->
        conf_opts = Application.get_env(:bonny, :kubeconf_opts, [])
        K8s.Conf.from_file(conf_path, conf_opts)

      _ ->
        K8s.Conf.from_service_account()
    end
  end

  defp config_path do
    System.get_env("BONNY_CONFIG_FILE") || Application.get_env(:bonny, :kubeconf_file)
  end
end
