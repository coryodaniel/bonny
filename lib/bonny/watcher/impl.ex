defmodule Bonny.Watcher.Impl do
  @moduledoc """
  Implementation logic for `Bonny.Watcher`
  """

  alias Bonny.Watcher.Impl
  alias K8s.Conf.RequestOptions
  require Logger

  @type t :: %__MODULE__{
          spec: Bonny.CRD.t(),
          config: K8s.Conf.t(),
          mod: atom(),
          resource_version: String.t() | nil
        }

  defstruct [:spec, :config, :mod, :resource_version]

  def new(operator) do
    %__MODULE__{
      config: Bonny.kubeconfig(),
      mod: operator,
      spec: apply(operator, :crd_spec, []),
      resource_version: nil
    }
  end

  @doc """
  Returns the current resource version
  """
  @spec get_resource_version(Impl.t()) :: {:ok, Impl.t()} | :error
  def get_resource_version(state = %Impl{spec: crd}) do
    path = Bonny.CRD.list_path(crd)

    case request(path, state) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        doc = Poison.decode!(body)
        state = %{state | resource_version: doc["metadata"]["resourceVersion"]}
        {:ok, state}

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        Logger.error("Error getting resource version; HTTP Error code: #{code} #{body}")
        :error

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Error getting resource version; #{reason}")
        :error
    end
  end

  @doc """
  Watches a CRD resource for `ADDED`, `MODIFIED`, and `DELETED` events from the Kubernetes API
  """
  @spec watch_for_changes(Impl.t(), pid()) :: nil
  def watch_for_changes(state = %Impl{}, to) do
    path = Bonny.CRD.watch_path(state.spec, state.resource_version)
    request(path, state, stream_to: to, recv_timeout: 5 * 60 * 1000)

    nil
  end

  @doc """
  Dispatches an `ADDED`, `MODIFIED`, and `DELETED` events to an operator
  """
  @spec dispatch(map, atom) :: nil
  def dispatch(%{"type" => "ADDED", "object" => object}, operator),
    do: do_dispatch(operator, :add, object)

  def dispatch(%{"type" => "MODIFIED", "object" => object}, operator),
    do: do_dispatch(operator, :modify, object)

  def dispatch(%{"type" => "DELETED", "object" => object}, operator),
    do: do_dispatch(operator, :delete, object)

  @spec do_dispatch(atom, atom, map) :: nil
  defp do_dispatch(operator, event, object) do
    Logger.debug("Dispatching to: #{inspect(operator)}.#{event}/1")
    apply(operator, event, [object])

    nil
  end

  # Parse `kubectl.kubernetes.io/last-applied-configuration` from plaintext formatted JSON
  defp parse_metadata(
         payload = %{
           "object" => %{
             "metadata" => %{
               "annotations" => %{"kubectl.kubernetes.io/last-applied-configuration" => chunk}
             }
           }
         }
       )
       when is_binary(chunk) do
    put_in(
      payload,
      ["object", "metadata", "annotations", "kubectl.kubernetes.io/last-applied-configuration"],
      parse_chunk(chunk)
    )
  end

  defp parse_metadata(payload), do: payload

  @doc """
  Receives a plaintext formatted JSON response line from `HTTPoison.AsyncChunk` and parses into a map
  """
  @spec parse_chunk(binary) :: map
  def parse_chunk(line) do
    line
    |> String.trim()
    |> Poison.decode!()
    |> parse_metadata
  end

  @spec request(binary, Impl.t(), keyword() | nil) :: {:ok, struct} | {:error, struct}
  defp request(path, state, opts \\ []) do
    request_options = RequestOptions.generate(state.config)

    headers =
      request_options.headers ++
        [{"Accept", "application/json"}, {"Content-Type", "application/json"}]

    options = Keyword.merge([ssl: request_options.ssl_options], opts)

    url = Path.join(state.config.url, path)
    HTTPoison.get(url, headers, options)
  end
end
