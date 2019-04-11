defmodule Bonny.Controller do
  @moduledoc """
  `Bonny.Controller` defines controller behaviours and generates boilerplate for generating Kubernetes manifests.

  > A custom controller is a controller that users can deploy and update on a running cluster, independently of the cluster’s own lifecycle. Custom controllers can work with any kind of resource, but they are especially effective when combined with custom resources. The Operator pattern is one example of such a combination. It allows developers to encode domain knowledge for specific applications into an extension of the Kubernetes API.

  Controllers allow for simple `add`, `modify`, `delete`, and `reconcile` handling of custom resources in the Kubernetes API.
  """

  @callback add(map()) :: :ok | :error | {:error, binary}
  @callback modify(map()) :: :ok | :error | {:error, binary}
  @callback delete(map()) :: :ok | :error | {:error, binary}
  @callback reconcile(map()) :: :ok | :error | {:error, binary}

  @doc false
  defmacro __using__(_opts) do
    quote do
      import Bonny.Controller
      Module.register_attribute(__MODULE__, :rule, accumulate: true)
      @behaviour Bonny.Controller
      @group nil
      @version nil
      @scope nil
      @names nil
      @before_compile Bonny.Controller
    end
  end

  @doc false
  defmacro __before_compile__(_env) do
    quote do
      @doc """
      Kubernetes CRD manifest spec
      """
      @spec crd_spec() :: Bonny.CRD.t()
      def crd_spec do
        module_components =
          __MODULE__
          |> Macro.to_string()
          |> String.split(".")
          |> Enum.reverse()

        name = Enum.at(module_components, 0)
        version = module_components |> Enum.at(1, "v1") |> String.downcase()

        %Bonny.CRD{
          group: @group || Bonny.Config.group(),
          scope: @scope || :namespaced,
          version: @version || version,
          names: @names || crd_spec_names(name)
        }
      end

      @doc """
      Kubernetes RBAC rules
      """
      def rules() do
        Enum.reduce(@rule, [], fn {api, resources, verbs}, acc ->
          rule = %{
            apiGroups: [api],
            resources: resources,
            verbs: verbs
          }

          [rule | acc]
        end)
      end

      defp crd_spec_names(name) do
        singular = Macro.underscore(name)

        %{
          plural: "#{singular}s",
          singular: singular,
          kind: name,
          shortNames: nil
        }
      end
    end
  end
end
