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

  @doc """
  Kubernetes service account name to run operator as.

  Name must consist of only lowercase letters and hyphens.

  Defaults to operator name.
  """
  def service_account() do
    service_account_name = Application.get_env(:bonny, :service_account_name, Bonny.name())

    service_account_name
    |> String.downcase()
    |> String.replace(~r/[^a-z-]/, "-\\1\\g{1}")
  end

  @doc """
  The name of the operator.

  Name must consist of only lowercase letters and hyphens.

  Defaults to "bonny"
  """
  def name() do
    operator_name = Application.get_env(:bonny, :operator_name, "bonny")

    operator_name
    |> String.downcase()
    |> String.replace(~r/[^a-z-]/, "-\\1\\g{1}")
  end

  @doc "List of all enabled controller modules"
  @spec controllers() :: list(atom)
  def controllers(), do: Application.get_env(:bonny, :controllers, [])

  defp config_path do
    System.get_env("BONNY_CONFIG_FILE") || Application.get_env(:bonny, :kubeconf_file)
  end
end
