defmodule Snake do
  @moduledoc """
  Snake provides a simple Gen Server to run a game of snake.
  """

  use GenServer
  require Logger

  @directions [:up, :down, :right, :left]

  @doc """
  Starts a snake game with the snake in the middle of the play field.
  The initial dimentions are given as the arguments to the GenServer.
  options: %{rows: rows, cols: cols}
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Initializes the state of the snake game and puts the snake in a
  random position and also sets the direction of travel
  """
  def init({rows, cols}) when rows > 0 and cols > 0 do
    snake_head = {:rand.uniform(rows) - 1, :rand.uniform(cols) - 1}
    food_pos = {:rand.uniform(rows) - 1, :rand.uniform(cols) - 1}

    snake_state = %{
      size: {rows, cols},
      head: snake_head,
      forward_direction: Enum.random(@directions),
      body: [snake_head],
      food_pos: food_pos,
      score: 0
    }

    Logger.debug(fn -> "Snake created with #{inspect(snake_state)}" end)
    {:ok, snake_state}
  end

  def init(_opts) do
    {:error, "improper options for the GenServer"}
  end

  @doc """
  Gets the current state of the snake game.
  """
  def get_state(pid), do: GenServer.call(pid, :get_state)

  @doc """
  Changes the directional heading of the snake
  """
  def change_direction(pid, new_direction),
    do: GenServer.call(pid, {:change_direction, new_direction})

  @doc """
  updates the game state for the next frame
  """
  def next_frame(pid), do: GenServer.call(pid, :next_frame)

  def handle_call(:get_state, _from, snake_state), do: {:reply, snake_state, snake_state}

  def handle_call({:change_direction, new_direction}, _from, snake_state) do
    new_state = %{snake_state | forward_direction: new_direction}
    {:reply, new_state, new_state}
  end

  def handle_call(:next_frame, _from, snake_state) do
    case update_snake(snake_state) do
      {:ok, snake_state} -> {:reply, {:ok, snake_state}, snake_state}
      {:hit_walls, snake_state} -> {:reply, {:hit_walls, snake_state}, snake_state}
      {:hit_body, snake_state} -> {:reply, {:hit_body, snake_state}, snake_state}
    end
  end

  # update function that return
  defp update_snake(snake_state) do
    with {:ok, snake_state} <- update_head(snake_state),
         {:ok, snake_state} <- check_outside_grid(snake_state),
         {:ok, snake_state} <- check_hit_body(snake_state),
         {:ok, snake_state} <- update_body(snake_state),
         do: {:ok, snake_state}
  end

  defp update_head(snake_state) do
    %{head: head, forward_direction: fd} = snake_state
    new_head = get_new_head(fd, head)
    {:ok, %{snake_state | head: new_head}}
  end

  defp get_new_head(:up, {hr, hc}), do: {hr - 1, hc}
  defp get_new_head(:down, {hr, hc}), do: {hr + 1, hc}
  defp get_new_head(:left, {hr, hc}), do: {hr, hc - 1}
  defp get_new_head(:right, {hr, hc}), do: {hr, hc + 1}

  defp check_outside_grid(%{size: {rows, cols}, head: {row, col}} = snake_state)
       when row < 0 or row >= rows or col < 0 or col >= cols,
       do: {:hit_walls, snake_state}

  defp check_outside_grid(%{size: {rows, cols}, head: {row, col}} = snake_state)
       when not (row < 0 or row >= rows or col < 0 or col >= cols),
       do: {:ok, snake_state}

  defp check_hit_body(%{head: head, body: body} = snake_state) do
    case head in body do
      true -> {:hit_body, snake_state}
      false -> {:ok, snake_state}
    end
  end

  defp update_body(%{head: head, food_pos: food_pos} = snake_state)
       when head == food_pos do
    %{size: {rows, cols}, head: head, body: body, score: score} = snake_state

    new_state = %{
      snake_state
      | food_pos: {:rand.uniform(rows) - 1, :rand.uniform(cols) - 1},
        score: score + 1,
        body: body ++ [head]
    }

    {:ok, new_state}
  end

  defp update_body(%{body: [_tail | rest], head: head, food_pos: food_pos} = snake_state)
       when head != food_pos do
    new_body = rest ++ [head]
    {:ok, %{snake_state | body: new_body}}
  end
end
