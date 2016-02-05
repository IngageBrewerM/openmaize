defmodule Openmaize.Login do
  @moduledoc """
  Plug to handle login.

  There are five options:

  * redirects - if true, which is the default, redirect on login
  * storage - storage method for the token
    * the default is :cookie
    * if storage is set to nil, redirects is automatically set to false
  * token_validity - length of validity of token (in minutes)
    * the default is 1440 minutes (one day)
  * unique_id - the name which is used to identify the user (in the database)
    * the default is `:name`
  * query_function - a custom function to query the database
    * if you are using Ecto, you will probably not need this

  ## Examples with Phoenix

  In the `web/router.ex` file, add the following line (you can use
  a different controller and route):

      post "/login", PageController, :login_user

  And then in the `page_controller.ex` file, add:

      plug Openmaize.Login when action in [:login_user]

  If you want to use sessionStorage to store the token (this will also set
  redirects to false):

      plug Openmaize.Login, [storage: nil] when action in [:login_user]

  If you want to use `email` to identify the user and have the token valid
  for just two hours:

      plug Openmaize.Login, [token_validity: 120, unique_id: :email] when action in [:login_user]

  ## Custom function to query the database

  To call a custom query function:

      plug Openmaize.Login, [query_function: &custom_query/2] when action in [:login_user]

  In the above example, this module will use the custom_query function
  instead of QueryTools.find_user.
  """

  import Openmaize.{Report, Token}
  alias Openmaize.{Config, QueryTools}

  @behaviour Plug

  def init(opts) do
    {redirects, storage} = case Keyword.get(opts, :storage, :cookie) do
             :cookie -> {Keyword.get(opts, :redirects, true), :cookie}
             nil -> {false, nil}
           end
    {redirects, storage, {0, Keyword.get(opts, :token_validity, 1440)},
     Keyword.get(opts, :unique_id, :name),
     Keyword.get(opts, :query_function, &QueryTools.find_user/2)}
  end

  @doc """
  Handle the login POST request.

  If the login is successful, a JSON Web Token will be returned.
  """
  def call(%Plug.Conn{params: %{"user" => user_params}} = conn,
           {redirects, storage, token_opts, uniq, query_func}) do
    unique = to_string(uniq)
    %{^unique => user_id, "password" => password} = user_params
    query_func.(user_id, uniq)
    |> check_pass(password, Config.hash_name)
    |> handle_auth(conn, {redirects, storage, token_opts, uniq})
  end

  defp check_pass(nil, _, _), do: Config.get_crypto_mod.dummy_checkpw
  defp check_pass(%{confirmed: false}, _, _),
    do: {:error, "You have to confirm your email address before continuing."}
  defp check_pass(user, password, hash_name) do
    %{^hash_name => hash} = user
    Config.get_crypto_mod.checkpw(password, hash) and user
  end

  defp handle_auth(false, conn, {redirects, _, _, _}) do
    handle_error(conn, "Invalid credentials", redirects)
  end
  defp handle_auth({:error, message}, conn, {redirects, _, _, _}) do
    handle_error(conn, message, redirects)
  end
  defp handle_auth(user, conn, opts) do
    add_token(conn, user, opts)
  end
end