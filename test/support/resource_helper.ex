defmodule Bonny.Test.ResourceHelper do
  @moduledoc false

  def to_string(pid) when is_pid(pid), do: pid_to_string(pid)
  def to_string(ref) when is_reference(ref), do: ref_to_string(ref)

  @spec ref_to_string(reference()) :: binary()
  def ref_to_string(ref), do: ref |> :erlang.ref_to_list() |> List.to_string()

  @spec pid_to_string(pid()) :: binary()
  def pid_to_string(pid), do: pid |> :erlang.pid_to_list() |> List.to_string()

  @spec string_to_ref(binary()) :: reference()
  def string_to_ref(ref), do: ref |> String.to_charlist() |> :erlang.list_to_ref()

  @spec string_to_pid(binary()) :: pid()
  def string_to_pid(pid), do: pid |> String.to_charlist() |> :erlang.list_to_pid()

  @spec widget(keyword()) :: Bonny.Resource.t()
  def widget(opts \\ []) do
    %{
      "apiVersion" => "example.com/v1",
      "kind" => "Widget",
      "metadata" => %{
        "name" => Keyword.get(opts, :name, "foo"),
        "namespace" => "default",
        "uid" => "foo-uid",
        "generation" => 1
      },
      "spec" => Keyword.get(opts, :spec, %{"foo" => "lorem ipsum"})
    }
  end

  @spec cog(keyword()) :: Bonny.Resource.t()
  def cog(opts \\ []) do
    %{
      "apiVersion" => "example.com/v1",
      "kind" => "Cog",
      "metadata" => %{
        "name" => Keyword.get(opts, :name, "bar"),
        "namespace" => "default",
        "uid" => "bar-uid",
        "generation" => 1
      },
      "spec" => Keyword.get(opts, :spec, %{"foo" => "lorem ipsum"})
    }
  end

  @test_resource_kinds %{v1: "TestResource", v2: "TestResourceV2", v3: "TestResourceV3"}
  @spec test_resource(binary(), atom(), pid(), reference(), keyword()) :: map()
  def test_resource(name, version, pid, ref, opts \\ []) do
    labels = Keyword.get(opts, :labels, %{})

    """
    apiVersion: example.com/v1
    kind: #{@test_resource_kinds[version]}
    metadata:
      namespace: default
      name: #{name}
    spec:
      pid: "#{pid_to_string(pid)}"
      ref: "#{ref_to_string(ref)}"
    """
    |> YamlElixir.read_from_string!()
    |> put_in(~w(metadata labels), labels)
  end
end
