defprotocol GenPool.Backend do
  @doc """
  Moduledoc for `GenPool.Backend`
  """

  @type backend :: term()
  @type state :: term()

  def new(opts \\ [])
  def put(backend, value)
  def get(backend)
end
