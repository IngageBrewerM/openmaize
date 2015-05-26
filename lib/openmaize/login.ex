defmodule Openmaize.Login do
  @moduledoc """
  Module to handle password authentication and the generation
  of tokens.
  """

  import Plug.Conn
  import Ecto.Query
  alias Openmaize.Config
  alias Openmaize.Token
  alias Openmaize.Tools

  @behaviour Plug

  def init(opts), do: opts

  def call(conn, opts) do
    %{"name" => name, "password" => password} = Map.get(conn.params, "user")
    case login_user(name, password) do
      false -> Tools.redirect_to_login(conn)
      user -> add_token(user, conn, opts, Config.storage_method)
    end
  end

  @doc """
  Check for the user in the database and check the password if the user
  is found.
  """
  def login_user(name, password) do
    from(user in Config.user_model,
    where: user.name == ^name,
    select: user)
    |> Config.repo.one
    |> check_user(password)
  end

  @doc """
  Perform a dummy check for no user.
  """
  def check_user(nil, _), do: Config.crypto.dummy_checkpw
  @doc """
  Check the user and user's password.
  """
  def check_user(user, password) do
    Config.crypto.checkpw(password, user.password_hash) and user
  end

  @doc """
  Generate a token and store it in a cookie.
  """
  def add_token(user, conn, opts, storage) when storage == "cookie" do
    opts = Keyword.put_new(opts, :http_only, true)
    {:ok, token} = generate_token(user)
    register_before_send(conn, &add_token_to_cookie(&1, token, opts))
  end
  @doc """
  Generate a token and send it in the response.
  """
  def add_token(user, conn, _opts, _storage) do
    token_string = "{\"Authorization\": \"Bearer #{generate_token(user)}\"}"
  end

  def generate_token(user) do
    # need to find a way of allowing users to define what goes in the token
    Map.take(user, [:name, :role])
    |> Map.merge(%{exp: token_expiry_secs})
    |> Token.encode
  end

  defp add_token_to_cookie(conn, token, opts) do
    put_resp_cookie(conn, "access_token", token, opts)
    |> Tools.redirect("users")
  end

  defp token_expiry_secs do
    current_time + Config.token_validity
  end 

  defp current_time do
    {mega, secs, _} = :os.timestamp
    mega * 1000000 + secs
  end
end