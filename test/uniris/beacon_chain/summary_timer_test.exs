defmodule Uniris.BeaconChain.SummaryTimerTest do
  use ExUnit.Case
  use ExUnitProperties

  alias Uniris.BeaconChain
  alias Uniris.BeaconChain.SubsetRegistry
  alias Uniris.BeaconChain.SummaryTimer

  setup do
    Enum.each(BeaconChain.list_subsets(), fn subset ->
      Registry.register(SubsetRegistry, subset, [])
    end)

    :ok
  end

  test "receive create_summary message after timer elapsed" do
    SummaryTimer.start_link([interval: "*/1 * * * * * *"], [])

    current = DateTime.utc_now()

    receive do
      {:create_summary, time} ->
        assert 1 == DateTime.diff(time, current)
    end
  end

  test "handle_info/3 receive a summary creation message" do
    {:ok, pid} = SummaryTimer.start_link([interval: "0 * * * * * *"], [])

    send(pid, :new_summary)

    Process.sleep(200)

    nb_create_summary_messages =
      self()
      |> :erlang.process_info(:messages)
      |> elem(1)
      |> Enum.filter(&match?({:create_summary, _}, &1))
      |> length()

    assert nb_create_summary_messages == 256
  end

  test "next_summary/2 should get the next summary time from a given date" do
    {:ok, pid} = SummaryTimer.start_link([interval: "0 * * * * * *"], [])
    now = DateTime.utc_now()
    next_summary_time = SummaryTimer.next_summary(pid, now)
    assert 1 == abs(now.minute - next_summary_time.minute)
  end

  property "previous_summaries/1 should retrieve the previous summary times from a date" do
    {:ok, pid} = SummaryTimer.start_link([interval: "* * * * * * *"], [])

    check all(previous_seconds <- StreamData.positive_integer()) do
      previous_summaries =
        SummaryTimer.previous_summaries(
          pid,
          DateTime.utc_now() |> DateTime.add(-previous_seconds)
        )

      assert length(previous_summaries) == previous_seconds
    end
  end
end
