-module(broadcaster).
-include("eventMessage.hrl").
-compile(export_all).

init() ->
	loop([]).
	
loop(WorkerPids) ->
	receive
		{broadcast,Msg,CurrentPids} -> 
			if length(CurrentPids) =/= length(WorkerPids) ->
					lists:foreach(fun(A) -> A ! {broadcast,Msg} end,CurrentPids),
					loop(CurrentPids);
			    length(CurrentPids) =:= length(WorkerPids) ->
					lists:foreach(fun(A) -> A ! {broadcast,Msg} end,WorkerPids),
					loop(WorkerPids)
			end;
		_ -> undefined
	end.