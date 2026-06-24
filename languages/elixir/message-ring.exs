# message-ring: lightweight-concurrency / message-passing overhead axis.
# 32 BEAM processes wired in a ring; main drives N laps by sending a 32-bit token to
# worker 0 and receiving it back from worker 31. Each worker receives, applies the
# deterministic LCG transform, and forwards to the next. Workers are spawned ONCE
# before the lap loop and run all N laps (spawn/teardown cost is cancelled by the
# differential I(n2)-I(n1)). BEAM processes + send/receive is the idiomatic
# cooperative handoff primitive; +S 1:1 (set in capture-beam.sh) keeps all 32
# processes on one scheduler OS thread.
import Bitwise

defmodule MessageRing do
  @ring_width 32
  @mask       0xFFFFFFFF
  @mod        1_000_000_007

  # Worker: loop for exactly n laps, applying the LCG transform each time.
  # `next` is the pid to forward to; for worker 31 that is the main controller.
  defp worker(id, next, n), do: worker_loop(id, next, n)

  defp worker_loop(_id, _next, 0), do: :ok
  defp worker_loop(id, next, laps) do
    receive do
      v ->
        v2 = (v * 1_103_515_245 + (id + 1)) &&& @mask
        send(next, v2)
        worker_loop(id, next, laps - 1)
    end
  end

  def run(n) do
    main = self()

    # Spawn workers 0..31 — we need each pid to wire the ring, so accumulate in
    # a list first, then link each to its successor.
    # Strategy: spawn all workers, pass each worker the pid of its successor.
    # Worker 31's successor is main.  Build right-to-left so the successor is
    # known before spawning.
    pids =
      Enum.reduce((@ring_width - 1)..0//-1, {[], main}, fn id, {acc, next} ->
        pid = spawn(fn -> worker(id, next, n) end)
        {[pid | acc], pid}
      end)
      |> elem(0)

    worker0 = hd(pids)

    # Drive N laps: send v to worker 0, receive transformed v from worker 31.
    v_final =
      Enum.reduce(1..n, 12345, fn _lap, v ->
        send(worker0, v)
        receive do
          v2 -> v2
        end
      end)

    IO.puts(rem(v_final, @mod))
    IO.puts(n * @ring_width)
  end
end

n =
  case System.argv() do
    [a | _] -> String.to_integer(a)
    _ -> 500
  end

MessageRing.run(n)
