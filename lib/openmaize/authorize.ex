defmodule Openmaize.Authorize do
  @moduledoc """
  Module to verify that users are authorized to access the requested pages
  / resources.

  Authorization is based on user roles, and so you will need a `role` entry
  in your user model.

  """

  import Plug.Conn
  import Openmaize.Errors
  alias Openmaize.Config

  @protected_roles Config.protected
  @protected Map.keys(Config.protected)

  @behaviour Plug

  def init(opts), do: opts

  @doc """
  Verify that the user is authorized to access the requested page / resource.
  """
  def call(conn, opts) do
    opts = {Keyword.get(opts, :redirects), Keyword.get(opts, :check)}
    run(conn, opts)
  end
  defp run(%{assigns: assigns} = conn, opts) do
    user = Map.get(assigns, :current_user)
    get_match(conn) |> is_permitted(user) |> finish(conn, opts)
  end

  defp is_permitted({{0, _}, path}, nil) do
    {:error, "You have to be logged in to view #{path}"}
  end
  defp is_permitted(_, nil), do: {:ok, nil}
  defp is_permitted({{0, match_len}, path}, %{role: role} = data) do
    match = :binary.part(path, {0, match_len})
    if role in Map.get(@protected_roles, match) do
      {:ok, data, path, match}
    else
      {:error, role, "You do not have permission to view #{path}"}
    end
  end
  defp is_permitted(_, data), do: {:ok, data}

  defp get_match(conn) do
    path = full_path(conn)
    {:binary.match(path, @protected), path}
  end

  defp finish({:ok, _}, conn, _), do: conn
  defp finish({:ok, _, _, _}, conn, {_, nil}), do: conn
  defp finish({:ok, data, path, match}, conn, {_, func}) do
    func.(conn, data, path, match) |> finish(conn, {nil, nil})
  end
  defp finish({:error, message}, conn, {false, _}), do: send_error(conn, 401, message)
  defp finish({:error, message}, conn, _), do: handle_error(conn, message)
  defp finish({:error, _, message}, conn, {false, _}), do: send_error(conn, 403, message)
  defp finish({:error, role, message}, conn, _), do: handle_error(conn, role, message)

end
