defmodule Bonny.Operator do
  @moduledoc """
  `Bonny.Operator` defines operator behaviours and generates boilerplate for generating Kubernetes manifests.
  """

  @callback add(map()) :: any
  @callback modify(map()) :: any
  @callback delete(map()) :: any

  @doc false
  defmacro __using__(_opts) do
    quote do
      import Bonny.Operator
      Module.register_attribute(__MODULE__, :rule, accumulate: true)
      @behaviour Bonny.Operator
      @group nil
      @version nil
      @scope nil
      @names nil
      @before_compile Bonny.Operator
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
          group: @group || "bonny.example.io",
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
          short_names: nil
        }
      end
    end
  end
end
